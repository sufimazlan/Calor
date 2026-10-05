//
//  TodayView.swift
//  Calor
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Home screen: today's total against the goal, goal progress, water, what to
/// do next, and today's entries grouped by meal. Snapping or uploading a photo
/// is the main action.
struct TodayView: View {
    /// Changes when the Calor logo is tapped; Today then scrolls to the top.
    let homeRequests: Int
    let goHome: () -> Void

    @Environment(\.scenePhase) private var scenePhase
    @State private var day = Calendar.current.startOfDay(for: .now)

    init(homeRequests: Int = 0, goHome: @escaping () -> Void = {}) {
        self.homeRequests = homeRequests
        self.goHome = goHome
    }

    var body: some View {
        NavigationStack {
            DayLog(day: day, homeRequests: homeRequests, goHome: goHome)
                .navigationTitle("Today")
        }
        // Roll over to the new day if the app was left open past midnight.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                day = Calendar.current.startOfDay(for: .now)
            }
        }
    }
}

private struct DayLog: View {
    let day: Date
    let homeRequests: Int
    let goHome: () -> Void

    private static let topID = "top"
    private static let expiryBannerID = "expiryBanner"
    private static let backupFailureID = "backupFailure"
    private static let backupPromptID = "backupPrompt"
    private static let budgetWarningID = "budgetWarning"

    private var showsExpiryBanner: Bool {
        InstallInfo.expiresSoon && InstallInfo.expirationDate != nil
    }

    private var showsBackupFailure: Bool {
        backupFolderBookmark != nil && !backupLastError.isEmpty
    }

    private var showsBackupPrompt: Bool {
        backupFolderBookmark == nil && !backupPromptDismissed && !entries.isEmpty
    }

    /// The first row on screen, so tapping the logo scrolls right to the top.
    private var firstRowID: String {
        if showsExpiryBanner { return Self.expiryBannerID }
        if showsBackupFailure { return Self.backupFailureID }
        if showsBackupPrompt { return Self.backupPromptID }
        if budgetWarning != nil { return Self.budgetWarningID }
        return Self.topID
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.carbsTargetG) private var carbsTarget = 0
    @AppStorage(SettingsKey.fatTargetG) private var fatTarget = 0
    @AppStorage(SettingsKey.rolloverEnabled) private var rolloverEnabled = false
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.backupFolderBookmark) private var backupFolderBookmark: Data?
    @AppStorage(SettingsKey.backupPromptDismissed) private var backupPromptDismissed = false
    @AppStorage(SettingsKey.backupLastError) private var backupLastError = ""
    @AppStorage(SettingsKey.healthEnabled) private var healthEnabled = false
    @AppStorage(SettingsKey.healthWorkoutShare) private var workoutShare = 0
    /// Only read so the budget warning updates after each analysis.
    @AppStorage(SettingsKey.aiSpendMicros) private var aiSpendMicros = 0
    @Query private var entries: [FoodEntry]
    /// Yesterday's entries, for rolling over unused calories.
    @Query private var yesterdayEntries: [FoodEntry]
    /// The last year of entries, for the logging streak.
    @Query private var yearEntries: [FoodEntry]

    @State private var isShowingQuickAdd = false
    @State private var isShowingSettings = false
    @State private var isSettingUpBackup = false
    @State private var isEditingProfile = false
    @State private var editingEntry: FoodEntry?
    /// Workout calories burned today, from Apple Health.
    @State private var workoutKcal = 0

    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var analysisPhoto: MealPhoto?

    init(day: Date, homeRequests: Int, goHome: @escaping () -> Void) {
        self.day = day
        self.homeRequests = homeRequests
        self.goHome = goHome
        let start = day
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.timestamp >= start && $0.timestamp < end },
            sort: \FoodEntry.timestamp
        )
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: start) ?? start
        _yesterdayEntries = Query(
            filter: #Predicate<FoodEntry> { $0.timestamp >= yesterday && $0.timestamp < start }
        )
        let yearAgo = Calendar.current.date(byAdding: .year, value: -1, to: start) ?? start
        _yearEntries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= yearAgo })
    }

    /// Calories left over yesterday (up to the limit), added to today's goal
    /// when rollover is on. Only counts if something was logged yesterday.
    private var rollover: Int {
        guard rolloverEnabled, !yesterdayEntries.isEmpty else { return 0 }
        let leftover = dailyGoal - yesterdayEntries.reduce(0) { $0 + $1.calories }
        return min(max(leftover, 0), SettingsKey.maxRollover)
    }

    /// Workout calories added to today's goal, by the share chosen in Settings.
    private var workoutBonus: Int {
        guard healthEnabled else { return 0 }
        return workoutKcal * workoutShare / 100
    }

    private var todayGoal: Int {
        dailyGoal + rollover + workoutBonus
    }

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var totalProteinG: Double {
        entries.compactMap(\.proteinG).reduce(0, +)
    }

    private var streak: Int {
        Streaks.current(loggedDays: Set(yearEntries.map(\.timestamp)))
    }

    private var whatsNext: String {
        Advice.whatsNext(
            eaten: totalCalories,
            goal: todayGoal,
            proteinG: totalProteinG,
            carbsG: entries.compactMap(\.carbsG).reduce(0, +),
            fatG: entries.compactMap(\.fatG).reduce(0, +),
            proteinTargetG: proteinTarget,
            diet: Profile(data: profileData)?.diet ?? .balanced,
            hasEntries: !entries.isEmpty
        )
    }

    /// A second tip shaped by the setup answers (what gets in the way, what the user wants).
    private var personalTip: String? {
        let profile = Profile(data: profileData)
        return Advice.personalTip(
            obstacle: profile?.obstacle,
            aspiration: profile?.aspiration,
            diet: profile?.diet ?? .balanced,
            remaining: todayGoal - totalCalories,
            streak: streak,
            healthScoreToday: HealthScore.meal(entries.map { (calories: $0.calories, score: $0.healthScore) })
        )
    }

    /// Shown from 80% of this month's Claude budget (PRD 9.3).
    private var budgetWarning: String? {
        _ = aiSpendMicros
        let budget = AIBudget()
        let spent = budget.spentThisMonth
        guard spent >= budget.monthlyLimit * 0.8 else { return nil }
        if spent + AIBudget.worstCaseCost(for: .photo(jpeg: Data(), hint: nil), model: .current, fallbacks: false) > budget.monthlyLimit {
            return "This month's Claude budget is used up, so photos can't be analysed until the 1st. Add meals another way below."
        }
        return "\(AIBudget.money(spent)) of this month's \(AIBudget.money(budget.monthlyLimit)) Claude budget used."
    }

    /// What the home screen widget shows.
    private var widgetValues: [String: Int] {
        ["eaten": totalCalories, "goal": todayGoal, "protein": Int(totalProteinG.rounded()),
         "proteinTarget": proteinTarget, "streak": streak]
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if showsExpiryBanner, let expiry = InstallInfo.expirationDate {
                    Section {
                        Label {
                            Text("Calor stops opening \(expiry.formatted(date: .abbreviated, time: .shortened)). Reinstall from Xcode on the Mac (⌘R) before then. Your meals are kept.")
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                        .id(Self.expiryBannerID)
                    }
                }

                if showsBackupFailure {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Label {
                                Text("Backup isn't working")
                                    .font(.headline)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            }
                            Text(backupLastError)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button("Fix backup") {
                                isSettingUpBackup = true
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.vertical, 4)
                        .id(Self.backupFailureID)
                    }
                }

                if showsBackupPrompt {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Protect your meals", systemImage: "externaldrive.badge.checkmark")
                                .font(.headline)
                            Text("Turn on automatic backup so your meals are safe even if the app is deleted.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack {
                                Button("Set up backup") {
                                    isSettingUpBackup = true
                                }
                                .buttonStyle(.borderedProminent)
                                Button("Not now") {
                                    backupPromptDismissed = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(.vertical, 4)
                        .id(Self.backupPromptID)
                    }
                }

                if let budgetWarning {
                    Section {
                        Label {
                            Text(budgetWarning)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        .font(.subheadline)
                        .id(Self.budgetWarningID)
                    }
                }

                Section {
                    CalorieSummary(eaten: totalCalories, goal: todayGoal,
                                   proteinG: Int(totalProteinG.rounded()), proteinTargetG: proteinTarget,
                                   rollover: rollover, workoutBonus: workoutBonus)
                        .frame(maxWidth: .infinity)
                        .id(Self.topID)
                } header: {
                    HStack {
                        Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                        Spacer()
                        StreakChip(streak: streak)
                    }
                }

                GoalSection()

                Section {
                    MacroProgressView(
                        proteinG: totalProteinG,
                        carbsG: entries.compactMap(\.carbsG).reduce(0, +),
                        fatG: entries.compactMap(\.fatG).reduce(0, +),
                        targets: MacroTargets(calorieGoal: dailyGoal, proteinTargetG: proteinTarget,
                                              carbsTargetG: carbsTarget, fatTargetG: fatTarget)
                    )
                } header: {
                    Text("Macros")
                } footer: {
                    if entries.contains(where: { $0.proteinG == nil }) {
                        Text("Some entries have no macros, so these totals may be low.")
                    }
                }

                WaterCard(day: day)

                Section("What's next") {
                    Label {
                        Text(whatsNext)
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                    }
                    if let personalTip {
                        Label {
                            Text(personalTip)
                        } icon: {
                            Image(systemName: "sparkles")
                                .foregroundStyle(.purple)
                        }
                    }
                }

                ForEach(MealType.allCases) { meal in
                    let mealEntries = entries.filter { $0.mealType == meal }
                    if !mealEntries.isEmpty {
                        Section {
                            ForEach(mealEntries) { entry in
                                LoggedEntryRow(entry: entry) {
                                    editingEntry = entry
                                }
                            }
                        } header: {
                            HStack {
                                Text(meal.title)
                                Spacer()
                                Text("\(mealEntries.reduce(0) { $0 + $1.calories }.formatted()) kcal")
                            }
                        } footer: {
                            if meal == entries.last?.mealType {
                                Text("Swipe right on a meal to log it again or star it.")
                            }
                        }
                    }
                }
            }
            .onChange(of: homeRequests) {
                withAnimation {
                    proxy.scrollTo(firstRowID, anchor: .top)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            photoButtons
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                CalorLogoButton(action: goHome)
            }
            ToolbarItem(placement: .topBarTrailing) {
                UserButton {
                    isEditingProfile = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Settings", systemImage: "gearshape") {
                    isShowingSettings = true
                }
            }
        }
        .task(id: WorkoutRefresh(day: day, isOn: healthEnabled && workoutShare > 0, isActive: scenePhase == .active)) {
            await loadWorkouts()
        }
        .onChange(of: widgetValues, initial: true) { _, values in
            if Calendar.current.isDateInToday(day) {
                WidgetSync.update(values)
            }
        }
        .sheet(isPresented: $isShowingQuickAdd) {
            QuickAddView()
        }
        .sheet(item: $editingEntry) { entry in
            EntryFormView(entry: entry)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $isSettingUpBackup) {
            BackupSetupSheet()
        }
        .sheet(isPresented: $isEditingProfile) {
            NavigationStack {
                ProfileEditView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { isEditingProfile = false }
                        }
                    }
            }
        }
        .sheet(item: $analysisPhoto) { photo in
            AnalysisView(photo: photo)
        }
        .fullScreenCover(isPresented: $isShowingCamera, onDismiss: analyzeCapturedImage) {
            CameraPicker { capturedImage = $0 }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    analysisPhoto = MealPhoto(image: image)
                }
                pickerItem = nil
            }
        }
    }

    /// Snap (camera) and Upload (photo library) are the main actions. The other
    /// ways (describe it, favourites, yesterday's meal, by hand) are one tap below.
    private var photoButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if CameraPicker.isAvailable {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Snap meal", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Upload", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // The simulator has no camera.
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Upload meal photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)

            Button("Describe it, repeat a meal, or type it in") {
                isShowingQuickAdd = true
            }
            .font(.footnote)
        }
        .padding()
        .background(.bar)
    }

    private func analyzeCapturedImage() {
        guard let capturedImage else { return }
        analysisPhoto = MealPhoto(image: capturedImage)
        self.capturedImage = nil
    }

    /// When to read workouts again: a new day, the setting changing, or coming back to the app.
    private struct WorkoutRefresh: Hashable {
        let day: Date
        let isOn: Bool
        let isActive: Bool
    }

    private func loadWorkouts() async {
        guard healthEnabled, workoutShare > 0, Calendar.current.isDateInToday(day) else {
            workoutKcal = 0
            return
        }
        guard scenePhase == .active else { return }
        if let kcal = try? await HealthService.workoutCalories(on: day) {
            workoutKcal = kcal
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self, WeightEntry.self, WaterLog.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(FoodEntry(mealType: .breakfast, name: "Roti canai with dhal", portion: "2 pieces", calories: 600,
                                           healthScore: 4))
    container.mainContext.insert(FoodEntry(mealType: .breakfast, name: "Teh tarik", portion: "1 cup", calories: 150))
    container.mainContext.insert(FoodEntry(mealType: .lunch, name: "Nasi lemak with fried chicken", portion: "1 plate", calories: 800))
    return TodayView()
        .modelContainer(container)
}
