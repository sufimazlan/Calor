//
//  TodayView.swift
//  Calor
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Home screen: today's total against the goal, what to do next, and today's
/// entries grouped by meal. Snapping or uploading a photo is the main action.
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

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.carbsTargetG) private var carbsTarget = 0
    @AppStorage(SettingsKey.fatTargetG) private var fatTarget = 0
    @AppStorage(SettingsKey.rolloverEnabled) private var rolloverEnabled = false
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @Query private var entries: [FoodEntry]
    /// Yesterday's entries, for rolling over unused calories.
    @Query private var yesterdayEntries: [FoodEntry]

    @State private var isAddingEntry = false
    @State private var isShowingSettings = false
    @State private var isEditingProfile = false
    @State private var editingEntry: FoodEntry?

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
    }

    /// Calories left over yesterday (up to the limit), added to today's goal
    /// when rollover is on. Only counts if something was logged yesterday.
    private var rollover: Int {
        guard rolloverEnabled, !yesterdayEntries.isEmpty else { return 0 }
        let leftover = dailyGoal - yesterdayEntries.reduce(0) { $0 + $1.calories }
        return min(max(leftover, 0), SettingsKey.maxRollover)
    }

    private var todayGoal: Int {
        dailyGoal + rollover
    }

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    private var totalProteinG: Double {
        entries.compactMap(\.proteinG).reduce(0, +)
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

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    CalorieSummary(eaten: totalCalories, goal: todayGoal,
                                   proteinG: Int(totalProteinG.rounded()), proteinTargetG: proteinTarget,
                                   rollover: rollover)
                        .frame(maxWidth: .infinity)
                        .id(Self.topID)
                } header: {
                    Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
                }

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

                Section("What's next") {
                    Label {
                        Text(whatsNext)
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                    }
                }

                ForEach(MealType.allCases) { meal in
                    let mealEntries = entries.filter { $0.mealType == meal }
                    if !mealEntries.isEmpty {
                        Section {
                            ForEach(mealEntries) { entry in
                                Button {
                                    editingEntry = entry
                                } label: {
                                    EntryRow(entry: entry)
                                }
                                .tint(.primary)
                            }
                            .onDelete { offsets in
                                for index in offsets {
                                    modelContext.delete(mealEntries[index])
                                }
                            }
                        } header: {
                            HStack {
                                Text(meal.title)
                                Spacer()
                                Text("\(mealEntries.reduce(0) { $0 + $1.calories }.formatted()) kcal")
                            }
                        }
                    }
                }
            }
            .onChange(of: homeRequests) {
                withAnimation {
                    proxy.scrollTo(Self.topID, anchor: .top)
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
        .sheet(isPresented: $isAddingEntry) {
            EntryFormView()
        }
        .sheet(item: $editingEntry) { entry in
            EntryFormView(entry: entry)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
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

    /// Snap (camera) and Upload (photo library) are the main actions.
    /// Manual entry is a small fallback for when a photo isn't possible.
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

            Button("Add manually instead") {
                isAddingEntry = true
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
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(FoodEntry(mealType: .breakfast, name: "Roti canai with dhal", portion: "2 pieces", calories: 600))
    container.mainContext.insert(FoodEntry(mealType: .breakfast, name: "Teh tarik", portion: "1 cup", calories: 150))
    container.mainContext.insert(FoodEntry(mealType: .lunch, name: "Nasi lemak with fried chicken", portion: "1 plate", calories: 800))
    return TodayView()
        .modelContainer(container)
}
