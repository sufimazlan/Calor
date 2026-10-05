//
//  OnboardingView.swift
//  Calor
//

import SwiftUI
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// First-launch setup, styled after Cal AI: one question per screen, then a
/// personal plan with a goal date and editable targets. Everything is worked
/// out on the phone. Shown until a profile is saved, and again from
/// "Answer step by step" (redo), which skips the welcome and info screens.
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.carbsTargetG) private var carbsTarget = 0
    @AppStorage(SettingsKey.fatTargetG) private var fatTarget = 0
    @AppStorage(SettingsKey.userName) private var savedName = ""
    @AppStorage(SettingsKey.rolloverEnabled) private var rolloverEnabled = false
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false

    @State private var profile: Profile
    @State private var name: String
    @State private var stepIndex = 0
    /// Questions that have an answer. Continue stays grey until then.
    @State private var answered: Set<Step>
    /// The user's edits on the plan screen, if any.
    @State private var goalOverride: Int?
    @State private var proteinOverride: Int?
    @State private var carbsOverride: Int?
    @State private var fatOverride: Int?
    @State private var editingTarget: PlanTarget?
    /// "Restore from a backup" on the welcome screen, e.g. after a reinstall.
    @State private var isPickingBackup = false
    @State private var pendingRestore: CalorBackup?
    @State private var restoreMessage: String?

    private let isRedo: Bool

    init(isRedo: Bool = false) {
        self.isRedo = isRedo
        let saved = isRedo ? Profile(data: UserDefaults.standard.data(forKey: SettingsKey.profile)) : nil
        _profile = State(initialValue: saved ?? Profile())
        _name = State(initialValue: UserDefaults.standard.string(forKey: SettingsKey.userName) ?? "")
        _answered = State(initialValue: isRedo ? Set(Step.allCases) : [])
    }

    // MARK: - Steps

    fileprivate enum Step: CaseIterable, Hashable {
        case welcome, name, sex, workouts, birthday, trendInfo, height, weight, goal
        case targetWeight, goalMotivation, speed, simplerWay, diet, obstacle, aspiration
        case potential, rollover, reminders, allDone, building, plan

        /// Questions with options to pick from.
        var needsAnswer: Bool {
            [.sex, .workouts, .goal, .diet, .obstacle, .aspiration].contains(self)
        }

        /// Wheel pickers don't sit well inside a vertical scroll view.
        var scrolls: Bool {
            ![.birthday, .height, .building].contains(self)
        }
    }

    private var steps: [Step] {
        var list: [Step] = isRedo ? [] : [.welcome]
        list += [.name, .sex, .workouts, .birthday]
        if !isRedo { list.append(.trendInfo) }
        list += [.height, .weight, .goal]
        if profile.goal != .maintain { list += [.targetWeight, .goalMotivation, .speed] }
        if !isRedo { list.append(.simplerWay) }
        list.append(.diet)
        if !isRedo { list += [.obstacle, .aspiration, .potential, .rollover, .reminders, .allDone] }
        list += [.building, .plan]
        return list
    }

    private var step: Step {
        steps[min(stepIndex, steps.count - 1)]
    }

    private var progress: Double {
        Double(stepIndex) / Double(max(steps.count - 1, 1))
    }

    // MARK: - Plan values

    private var goalValue: Int { goalOverride ?? profile.suggestedCalories }
    private var proteinValue: Int { proteinOverride ?? profile.suggestedProteinG }
    private var macros: MacroTargets {
        MacroTargets(calorieGoal: goalValue, proteinTargetG: proteinValue,
                     carbsTargetG: carbsOverride ?? 0, fatTargetG: fatOverride ?? 0)
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome && step != .building {
                OnboardingTopBar(progress: progress, showsBack: true, onBack: goBack)
            }

            Group {
                if step.scrolls {
                    ScrollView {
                        stepContent
                            .padding(.horizontal, 24)
                            .padding(.vertical, 24)
                    }
                    .scrollIndicators(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                } else {
                    stepContent
                        .padding(24)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .frame(maxHeight: .infinity)
            .id(step)
            .transition(.opacity)

            footer
        }
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.25), value: stepIndex)
        .onChange(of: profile.goal) {
            profile.normalize()
        }
        .onChange(of: profile.weightKg) {
            profile.normalize()
        }
        .sheet(item: $editingTarget) { target in
            TargetEditSheet(target: target, value: currentValue(of: target)) { newValue in
                switch target {
                case .calories: goalOverride = newValue
                case .protein: proteinOverride = newValue
                case .carbs: carbsOverride = newValue
                case .fat: fatOverride = newValue
                }
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .name: nameStep
        case .sex: sexStep
        case .workouts: workoutsStep
        case .birthday: birthdayStep
        case .trendInfo:
            VStack(spacing: 32) {
                OnboardingTitle(title: "Designed to help you stay on track")
                WeightTrendCard()
            }
        case .height: heightStep
        case .weight: weightStep
        case .goal: goalStep
        case .targetWeight: targetWeightStep
        case .goalMotivation: goalMotivationStep
        case .speed: speedStep
        case .simplerWay:
            VStack(spacing: 32) {
                OnboardingTitle(title: "A simpler way to stay on track",
                                subtitle: "Snap meals in seconds, follow your plan, and watch your progress add up.")
                SimplerWayCard()
            }
        case .diet: dietStep
        case .obstacle: obstacleStep
        case .aspiration: aspirationStep
        case .potential:
            VStack(spacing: 32) {
                OnboardingTitle(title: "You have great potential to crush your goal")
                WeightTransitionCard()
            }
        case .rollover: rolloverStep
        case .reminders: remindersStep
        case .allDone: allDoneStep
        case .building:
            PlanBuildingView(onFinished: goForward)
        case .plan: planStep
        }
    }

    // MARK: - Individual steps

    private var welcomeStep: some View {
        VStack(spacing: 28) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 30, height: 30)
                    .clipShape(Circle())
                Text("Calor")
                    .font(.title3.bold())
            }
            ScanMockup()
            Text("Calorie tracking\nmade easy")
                .font(.system(size: 36, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: 32) {
            OnboardingTitle(title: "What should we call you?",
                            subtitle: "Shown at the top of the app. You can add a photo later in your profile.")
            TextField("Your name (optional)", text: $name)
                .textContentType(.name)
                .font(.title3)
                .padding(18)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(OnboardingStyle.cardBorder))
        }
    }

    private var sexStep: some View {
        VStack(spacing: 48) {
            OnboardingTitle(title: "Choose your sex", subtitle: "This helps calculate how many calories you burn.")
            VStack(spacing: 12) {
                ForEach(Sex.allCases) { sex in
                    OptionCard(title: sex.title, isSelected: isAnswered(.sex) && profile.sex == sex) {
                        answer(.sex) { $0.sex = sex }
                    } icon: {
                        Text(sex.symbol).font(.title2)
                    }
                }
            }
        }
    }

    private var workoutsStep: some View {
        VStack(spacing: 48) {
            OnboardingTitle(title: "How many workouts do you do per week?",
                            subtitle: "This will be used to calibrate your custom plan.")
            VStack(spacing: 12) {
                ForEach(ActivityLevel.choices) { level in
                    OptionCard(title: level.workouts, detail: level.detail,
                               isSelected: isAnswered(.workouts) && profile.activity == level) {
                        answer(.workouts) { $0.activity = level }
                    } icon: {
                        DotsIcon(count: level.dots)
                    }
                }
            }
        }
    }

    private var birthdayStep: some View {
        VStack(spacing: 40) {
            OnboardingTitle(title: "When were you born?",
                            subtitle: "This will be taken into account when calculating your daily nutrition goals.")
            DatePicker("Birthday", selection: $profile.birthDate, in: Profile.birthDateRange,
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
        }
    }

    private var heightStep: some View {
        VStack(spacing: 32) {
            OnboardingTitle(title: "What is your height?",
                            subtitle: "This will be taken into account when calculating your daily nutrition goals.")
            UnitToggle(left: "ft, in", right: "cm", isLeft: $profile.usesFeetAndInches)
            if profile.usesFeetAndInches {
                HStack(spacing: 0) {
                    Picker("Feet", selection: feetBinding) {
                        ForEach(3...7, id: \.self) { Text("\($0) ft").tag($0) }
                    }
                    Picker("Inches", selection: inchesBinding) {
                        ForEach(0...11, id: \.self) { Text("\($0) in").tag($0) }
                    }
                }
                .pickerStyle(.wheel)
            } else {
                Picker("Height", selection: $profile.heightCm) {
                    ForEach(Profile.heightRange, id: \.self) { Text("\($0) cm").tag($0) }
                }
                .pickerStyle(.wheel)
            }
        }
    }

    private var weightStep: some View {
        VStack(spacing: 40) {
            OnboardingTitle(title: "What is your weight?",
                            subtitle: "This will be taken into account when calculating your daily nutrition goals.")
            UnitToggle(left: "lbs", right: "kg", isLeft: $profile.usesPounds)
            VStack(spacing: 8) {
                Text("Current weight")
                    .foregroundStyle(.secondary)
                Text(profile.weightText(profile.weightKg))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            WeightRuler(value: displayWeight(\.weightKg), range: displayRange(for: Profile.weightRange))
                .id(profile.usesPounds)
        }
    }

    private var goalStep: some View {
        VStack(spacing: 48) {
            OnboardingTitle(title: "What is your goal?",
                            subtitle: "This helps us generate a plan for your calorie intake.")
            VStack(spacing: 12) {
                ForEach(WeightGoal.allCases) { goal in
                    OptionCard(title: goal.title, symbol: goal.symbol,
                               isSelected: isAnswered(.goal) && profile.goal == goal) {
                        answer(.goal) { $0.goal = goal }
                    }
                }
            }
        }
    }

    private var targetWeightStep: some View {
        let targetRange = profile.goal == .lose
            ? Profile.weightRange.lowerBound...max(profile.weightKg - 0.1, Profile.weightRange.lowerBound + 1)
            : min(profile.weightKg + 0.1, Profile.weightRange.upperBound - 1)...Profile.weightRange.upperBound

        return VStack(spacing: 48) {
            OnboardingTitle(title: "What is your desired weight?")
            VStack(spacing: 8) {
                Text(profile.goal.title)
                    .foregroundStyle(.secondary)
                Text(profile.weightText(profile.targetWeightKg))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            WeightRuler(value: displayWeight(\.targetWeightKg), range: displayRange(for: targetRange))
                .id("\(profile.usesPounds)-\(profile.goal)")
        }
    }

    private var goalMotivationStep: some View {
        let amount = profile.weightText(profile.kgToGoal)
        let verb = profile.goal == .lose ? "Losing" : "Gaining"
        return VStack(spacing: 16) {
            Text("\(verb) \(Text(amount).foregroundStyle(OnboardingStyle.accent)) starts with a plan!")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
            Text("To help you make steady progress, Calor builds a plan from your habits, goals and timeline.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 140)
    }

    private var speedStep: some View {
        let zone = SpeedZone(pace: profile.paceKgPerWeek, goal: profile.goal)
        let calories = profile.suggestedCalories
        let date = profile.goalDate(dailyGoal: calories)

        return VStack(spacing: 32) {
            OnboardingTitle(title: "How fast do you want to reach your goal?")
            VStack(spacing: 20) {
                Text(profile.goal == .lose ? "Weight loss speed per week" : "Weight gain speed per week")
                    .font(.subheadline)
                Text(profile.weightText(profile.paceKgPerWeek))
                    .font(.system(size: 34, weight: .bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                HStack {
                    ForEach(SpeedZone.allCases, id: \.self) { item in
                        VStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.title2)
                            Text(item.title)
                                .font(.caption)
                        }
                        .foregroundStyle(item == zone ? OnboardingStyle.accent : .primary)
                        .frame(maxWidth: .infinity)
                    }
                }
                Slider(value: $profile.paceKgPerWeek, in: profile.goal.paceRange, step: 0.1)
                    .tint(.primary)
                    .sensoryFeedback(.selection, trigger: profile.paceKgPerWeek)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let date {
                    Text("You should reach your goal in \(Text(durationText(until: date)).foregroundStyle(OnboardingStyle.accent))")
                        .font(.headline)
                }
                Text(zone.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Daily calorie goal: \(calories.formatted()) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if profile.isAtMinimum {
                    Text("That's the safe minimum, so expect about \(profile.weightText(profile.kgPerWeek(dailyGoal: calories))) a week.")
                        .font(.footnote)
                        .foregroundStyle(OnboardingStyle.accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(OnboardingStyle.softFill, in: .rect(cornerRadius: 16))
        }
    }

    private var dietStep: some View {
        VStack(spacing: 28) {
            OnboardingTitle(title: "Do you follow a specific diet?",
                            subtitle: "Calor will suggest foods that fit it.")
            VStack(spacing: 12) {
                ForEach(DietType.allCases) { diet in
                    OptionCard(title: diet.title, symbol: diet.symbol,
                               isSelected: isAnswered(.diet) && profile.diet == diet) {
                        answer(.diet) { $0.diet = diet }
                    }
                }
            }
        }
    }

    private var obstacleStep: some View {
        VStack(spacing: 28) {
            OnboardingTitle(title: "What's stopping you from reaching your goals?")
            VStack(spacing: 12) {
                ForEach(Obstacle.allCases) { obstacle in
                    OptionCard(title: obstacle.title, symbol: obstacle.symbol,
                               isSelected: isAnswered(.obstacle) && profile.obstacle == obstacle) {
                        answer(.obstacle) { $0.obstacle = obstacle }
                    }
                }
            }
        }
    }

    private var aspirationStep: some View {
        VStack(spacing: 48) {
            OnboardingTitle(title: "What would you like to accomplish?")
            VStack(spacing: 12) {
                ForEach(Aspiration.allCases) { aspiration in
                    OptionCard(title: aspiration.title, symbol: aspiration.symbol,
                               isSelected: isAnswered(.aspiration) && profile.aspiration == aspiration) {
                        answer(.aspiration) { $0.aspiration = aspiration }
                    }
                }
            }
        }
    }

    private var rolloverStep: some View {
        VStack(alignment: .leading, spacing: 40) {
            VStack(alignment: .leading, spacing: 10) {
                OnboardingTitle(title: "Rollover extra calories to the next day?")
                Text("Rollover up to \(Text("\(SettingsKey.maxRollover) kcal").foregroundStyle(.blue))")
                    .font(.subheadline.weight(.medium))
            }
            RolloverIllustration()
                .frame(maxWidth: .infinity)
        }
    }

    private var remindersStep: some View {
        VStack(spacing: 40) {
            VStack(spacing: 12) {
                Text("Stay on track with meal reminders")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)
                Text("Calor can remind you to log breakfast, lunch and dinner. You can change the times in Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 60)
            ReminderMockup()
        }
    }

    private var allDoneStep: some View {
        VStack(spacing: 20) {
            CelebrationBadge()
                .padding(.top, 40)
            Label("All done!", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(OnboardingStyle.accent)
            Text("Time to generate your custom plan!")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Plan

    private var planHeadline: String {
        let amount = profile.weightText(profile.kgToGoal)
        switch profile.goal {
        case .maintain:
            return "Goal: stay at \(profile.weightText(profile.weightKg))"
        case .lose, .gain:
            let verb = profile.goal == .lose ? "lose" : "gain"
            if let date = profile.goalDate(dailyGoal: goalValue) {
                return "Goal: \(verb) \(amount) by \(date.formatted(.dateTime.day().month(.wide)))"
            }
            return "Goal: \(verb) \(amount)"
        }
    }

    private var planStep: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark")
                .font(.title3.bold())
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 44, height: 44)
                .background(Color.primary, in: Circle())
            Text(planHeadline)
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)

            if profile.goal != .maintain, let date = profile.goalDate(dailyGoal: goalValue) {
                GoalCurveCard(startLabel: "Now",
                              endLabel: date.formatted(.dateTime.day().month(.abbreviated).year()),
                              targetText: profile.weightText(profile.targetWeightKg),
                              isLosing: profile.goal == .lose)
            }

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your daily recommendation")
                        .font(.headline)
                    Text("Tap any number to edit it")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                TargetTile(title: "Calories", value: goalValue.formatted(), symbol: "flame.fill",
                           tint: .primary, isLarge: true) { editingTarget = .calories }
                HStack(spacing: 10) {
                    TargetTile(title: "Protein", value: "\(proteinValue)g", symbol: "fish.fill",
                               tint: .red) { editingTarget = .protein }
                    TargetTile(title: "Carbs", value: "\(macros.carbsG)g", symbol: "leaf.fill",
                               tint: .orange) { editingTarget = .carbs }
                    TargetTile(title: "Fats", value: "\(macros.fatG)g", symbol: "drop.fill",
                               tint: .blue) { editingTarget = .fat }
                }
                if goalOverride != nil || proteinOverride != nil || carbsOverride != nil || fatOverride != nil {
                    Button("Use calculated targets") {
                        goalOverride = nil
                        proteinOverride = nil
                        carbsOverride = nil
                        fatOverride = nil
                    }
                    .font(.subheadline)
                }
            }
            .padding(18)
            .background(OnboardingStyle.softFill.opacity(0.7), in: .rect(cornerRadius: 24))

            GoalProjectionView(maintenance: profile.maintenanceCalories, goal: goalValue,
                               minimum: profile.minimumCalories)
                .padding(18)
                .background(OnboardingStyle.softFill.opacity(0.7), in: .rect(cornerRadius: 24))
        }
    }

    private func currentValue(of target: PlanTarget) -> Int {
        switch target {
        case .calories: goalValue
        case .protein: proteinValue
        case .carbs: macros.carbsG
        case .fat: macros.fatG
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footer: some View {
        switch step {
        case .building:
            EmptyView()
        case .welcome:
            footerContainer {
                PrimaryPillButton(title: "Get Started", action: goForward)
                if let restoreMessage {
                    Text(restoreMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                secondaryButton("Restore from a backup") {
                    isPickingBackup = true
                }
                .fileImporter(isPresented: $isPickingBackup, allowedContentTypes: [.json]) { result in
                    switch result {
                    case .success(let url):
                        do {
                            pendingRestore = try BackupManager.readBackup(from: url)
                        } catch {
                            restoreMessage = "That file isn't a Calor backup."
                        }
                    case .failure(let error):
                        restoreMessage = error.localizedDescription
                    }
                }
                .confirmationDialog("Restore this backup?", isPresented: restoreDialogBinding,
                                    titleVisibility: .visible, presenting: pendingRestore) { backup in
                    Button("Restore \(backup.entries.count) meals") {
                        restore(backup)
                    }
                } message: { backup in
                    Text("Backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)), with your profile and settings.")
                }
            }
        case .rollover:
            footerContainer {
                PrimaryPillButton(title: "Yes") {
                    rolloverEnabled = true
                    goForward()
                }
                secondaryButton("No") {
                    rolloverEnabled = false
                    goForward()
                }
            }
        case .reminders:
            footerContainer {
                PrimaryPillButton(title: "Turn on reminders", systemImage: "bell.fill") {
                    Task {
                        let granted = await MealReminders.requestPermission()
                        remindersEnabled = granted
                        await MealReminders.reschedule()
                        goForward()
                    }
                }
                secondaryButton("Not now") {
                    remindersEnabled = false
                    goForward()
                }
            }
        case .plan:
            footerContainer {
                PrimaryPillButton(title: isRedo ? "Save" : "Let's get started!", action: finish)
            }
        default:
            footerContainer {
                PrimaryPillButton(title: "Continue", isEnabled: !step.needsAnswer || isAnswered(step),
                                  action: goForward)
            }
        }
    }

    private func footerContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 8)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
    }

    // MARK: - Navigation

    private func isAnswered(_ step: Step) -> Bool {
        answered.contains(step)
    }

    private func answer(_ step: Step, _ change: (inout Profile) -> Void) {
        change(&profile)
        answered.insert(step)
    }

    private func goForward() {
        if step == .plan {
            finish()
            return
        }
        let nextIndex = min(stepIndex + 1, steps.count - 1)
        if steps[nextIndex] == .building {
            // Answers may have changed, so start the plan from fresh numbers.
            goalOverride = nil
            proteinOverride = nil
            carbsOverride = nil
            fatOverride = nil
        }
        stepIndex = nextIndex
    }

    private func goBack() {
        guard stepIndex > 0 else {
            if isRedo { dismiss() }
            return
        }
        stepIndex -= 1
        if step == .building {
            stepIndex -= 1
        }
    }

    private var restoreDialogBinding: Binding<Bool> {
        Binding(get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } })
    }

    /// Restores meals, profile and settings. If the backup has a profile, saving
    /// it switches the app straight to the main tabs; otherwise setup continues.
    private func restore(_ backup: CalorBackup) {
        do {
            try BackupManager.restore(backup, context: modelContext)
            Task { await MealReminders.applyRestoredSettings() }
            if backup.profile == nil {
                name = backup.userName
                restoreMessage = "Restored \(backup.entries.count) meals. Now answer a few questions to set your goal."
            }
        } catch {
            restoreMessage = "Restore failed: \(error.localizedDescription)"
        }
    }

    private func finish() {
        savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        dailyGoal = goalValue
        proteinTarget = proteinValue
        carbsTarget = carbsOverride ?? 0
        fatTarget = fatOverride ?? 0
        let finished = ProfileEditView.keepingOrStartingPlan(profile, saved: Profile(data: profileData))
        // Saved last: on first launch this switches the app to the main tabs.
        profileData = finished.data
        // The weight from setup is the first weigh-in (or a new one after a redo).
        WeightLog.recordProfileWeight(finished.weightKg, context: modelContext)
        if isRedo {
            dismiss()
        }
    }

    // MARK: - Units

    private var totalInches: Int {
        Int((Double(profile.heightCm) / 2.54).rounded())
    }

    private var feetBinding: Binding<Int> {
        Binding(get: { totalInches / 12 },
                set: { setHeight(feet: $0, inches: totalInches % 12) })
    }

    private var inchesBinding: Binding<Int> {
        Binding(get: { totalInches % 12 },
                set: { setHeight(feet: totalInches / 12, inches: $0) })
    }

    private func setHeight(feet: Int, inches: Int) {
        let cm = Int((Double(feet * 12 + inches) * 2.54).rounded())
        profile.heightCm = min(max(cm, Profile.heightRange.lowerBound), Profile.heightRange.upperBound)
    }

    private static let poundsPerKg = 2.20462

    /// A weight in the units on screen. Stored in kg, rounded to 0.1.
    private func displayWeight(_ keyPath: WritableKeyPath<Profile, Double>) -> Binding<Double> {
        Binding(
            get: { profile.usesPounds ? profile[keyPath: keyPath] * Self.poundsPerKg : profile[keyPath: keyPath] },
            set: { shown in
                let kg = profile.usesPounds ? shown / Self.poundsPerKg : shown
                profile[keyPath: keyPath] = (kg * 10).rounded() / 10
            }
        )
    }

    private func displayRange(for kgRange: ClosedRange<Double>) -> ClosedRange<Double> {
        guard profile.usesPounds else { return kgRange }
        let lower = (kgRange.lowerBound * Self.poundsPerKg).rounded(.up)
        let upper = (kgRange.upperBound * Self.poundsPerKg).rounded(.down)
        return lower...max(upper, lower + 1)
    }

    private func durationText(until date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: .now, to: date).day ?? 0
        if days < 56 {
            let weeks = max(1, Int((Double(days) / 7).rounded()))
            return weeks == 1 ? "1 week" : "\(weeks) weeks"
        }
        let months = Int((Double(days) / 30.4).rounded())
        return "\(months) months"
    }
}

// MARK: - Speed zones

private enum SpeedZone: CaseIterable {
    case slow, recommended, fast

    init(pace: Double, goal: WeightGoal) {
        let limits = goal == .gain ? (0.2, 0.5) : (0.4, 0.8)
        if pace < limits.0 - 0.001 {
            self = .slow
        } else if pace <= limits.1 + 0.001 {
            self = .recommended
        } else {
            self = .fast
        }
    }

    var title: String {
        switch self {
        case .slow: "Slow"
        case .recommended: "Recommended"
        case .fast: "Fast"
        }
    }

    var symbol: String {
        switch self {
        case .slow: "tortoise.fill"
        case .recommended: "hare.fill"
        case .fast: "bolt.fill"
        }
    }

    var description: String {
        switch self {
        case .slow: "Gentle and easy to keep up, but results take longer."
        case .recommended: "The most balanced pace: motivating and realistic for most people."
        case .fast: "This pace moves quickly. Staying consistent will be key."
        }
    }
}

// MARK: - Plan pieces

/// Which number is being edited on the plan screen.
enum PlanTarget: String, Identifiable {
    case calories, protein, carbs, fat

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calories: "Calories"
        case .protein: "Protein"
        case .carbs: "Carbs"
        case .fat: "Fats"
        }
    }

    var unit: String { self == .calories ? "kcal" : "g" }
    var range: ClosedRange<Int> { self == .calories ? 1000...5000 : 0...500 }
    var step: Int { self == .calories ? 50 : 5 }
}

/// A number on the plan screen with a pencil, tap to edit.
private struct TargetTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color
    var isLarge = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: symbol)
                        .font(.caption)
                        .foregroundStyle(tint)
                        .frame(width: 28, height: 28)
                        .background(tint.opacity(0.12), in: Circle())
                    Spacer()
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(value)
                    .font(isLarge ? .system(size: 36, weight: .bold) : .headline)
                    .monospacedDigit()
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(OnboardingStyle.cardBorder))
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) \(value), edit")
    }
}

/// Small sheet to change one plan number.
struct TargetEditSheet: View {
    let target: PlanTarget
    let onSave: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var value: Int

    init(target: PlanTarget, value: Int, onSave: @escaping (Int) -> Void) {
        self.target = target
        self.onSave = onSave
        _value = State(initialValue: value)
    }

    var body: some View {
        NavigationStack {
            Form {
                Stepper(value: $value, in: target.range, step: target.step) {
                    LabeledContent(target.title, value: "\(value.formatted()) \(target.unit)")
                        .monospacedDigit()
                }
            }
            .navigationTitle("Edit \(target.title.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(value)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(220)])
    }
}

/// "We're setting everything up for you": a short animated count-up,
/// then moves on to the plan by itself.
private struct PlanBuildingView: View {
    let onFinished: () -> Void

    @State private var percent = 0
    private let items = ["Calories", "Carbs", "Protein", "Fats"]

    private var status: String {
        switch percent {
        case ..<25: "Calculating your BMR…"
        case ..<50: "Applying your activity level…"
        case ..<75: "Setting your macros…"
        default: "Finalizing results…"
        }
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("\(percent)%")
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text("We're setting everything up for you")
                .font(.system(size: 28, weight: .bold))
                .multilineTextAlignment(.center)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule()
                        .fill(LinearGradient(colors: [.red.opacity(0.7), .blue.opacity(0.7)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: geometry.size.width * Double(percent) / 100)
                }
            }
            .frame(height: 8)
            Text(status)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 12) {
                Text("Daily recommendation for")
                    .font(.headline)
                ForEach(items.indices, id: \.self) { index in
                    HStack {
                        Text("•  \(items[index])")
                        Spacer()
                        if percent >= (index + 1) * 22 {
                            Image(systemName: "checkmark.circle.fill")
                                .transition(.scale)
                        }
                    }
                }
            }
            .padding(20)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(OnboardingStyle.cardBorder))
            .animation(.spring, value: percent)
            Spacer()
        }
        .task {
            do {
                for value in 0...100 {
                    percent = value
                    try await Task.sleep(for: .milliseconds(22))
                }
                try await Task.sleep(for: .milliseconds(350))
            } catch {
                return // Left the screen early.
            }
            onFinished()
        }
    }
}

#Preview("First launch") {
    OnboardingView()
        .modelContainer(for: [FoodEntry.self, WeightEntry.self, WaterLog.self], inMemory: true)
}

#Preview("Redo") {
    OnboardingView(isRedo: true)
        .modelContainer(for: [FoodEntry.self, WeightEntry.self, WaterLog.self], inMemory: true)
}
