//
//  ProfileEditView.swift
//  Calor
//

import SwiftUI

/// Edit the profile from Settings. Saving recalculates the calorie goal and protein target.
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0

    @State private var profile: Profile
    @State private var isRedoingSetup = false
    /// The user's tweaks to the calculated targets, if any.
    @State private var adjustedGoal: Int?
    @State private var adjustedProtein: Int?
    /// Saved profile when the step-by-step setup was opened, to tell if it was saved.
    @State private var profileDataBeforeRedo: Data?

    init() {
        let saved = Profile(data: UserDefaults.standard.data(forKey: SettingsKey.profile))
        _profile = State(initialValue: saved ?? Profile())
    }

    private var goalValue: Int {
        adjustedGoal ?? profile.suggestedCalories
    }

    private var proteinValue: Int {
        adjustedProtein ?? profile.suggestedProteinG
    }

    var body: some View {
        Form {
            Section {
                Button("Answer step by step instead", systemImage: "list.number") {
                    profileDataBeforeRedo = profileData
                    isRedoingSetup = true
                }
            } footer: {
                Text("Goes through the same questions as when you first installed the app.")
            }

            Section("About you") {
                Picker("Sex", selection: $profile.sex) {
                    ForEach(Sex.allCases) { sex in
                        Text(sex.title).tag(sex)
                    }
                }
                Picker("Birth year", selection: $profile.birthYear) {
                    ForEach(Array(Profile.birthYearRange.reversed()), id: \.self) { year in
                        Text(String(year)).tag(year)
                    }
                }
                Picker("Height", selection: $profile.heightCm) {
                    ForEach(Profile.heightRange, id: \.self) { cm in
                        Text("\(cm) cm").tag(cm)
                    }
                }
                Picker("Weight", selection: $profile.weightKg) {
                    ForEach(Profile.weightRange, id: \.self) { kg in
                        Text("\(kg) kg").tag(kg)
                    }
                }
            }

            Section("Lifestyle") {
                Picker("Activity", selection: $profile.activity) {
                    ForEach(ActivityLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                Picker("Goal", selection: $profile.goal) {
                    ForEach(WeightGoal.allCases) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                if profile.goal != .maintain {
                    Picker("Pace", selection: $profile.paceKgPerWeek) {
                        ForEach(profile.goal.paceOptions, id: \.self) { pace in
                            Text("\(pace.formatted()) kg/week").tag(pace)
                        }
                    }
                }
            }

            Section {
                Stepper(value: Binding(get: { goalValue }, set: { adjustedGoal = $0 }),
                        in: 1000...5000, step: 50) {
                    LabeledContent("Daily goal", value: "\(goalValue.formatted()) kcal")
                }
                Stepper(value: Binding(get: { proteinValue }, set: { adjustedProtein = $0 }),
                        in: 0...300, step: 5) {
                    LabeledContent("Protein target", value: "\(proteinValue) g a day")
                }
                if adjustedGoal != nil || adjustedProtein != nil {
                    Button("Use calculated targets (\(profile.suggestedCalories.formatted()) kcal, \(profile.suggestedProteinG) g)") {
                        adjustedGoal = nil
                        adjustedProtein = nil
                    }
                }
            } header: {
                Text("New targets")
            } footer: {
                Text("Calculated from your answers above. Use − / + to fine-tune. Saving replaces your current goal (\(dailyGoal.formatted()) kcal) and protein target.")
            }

            Section {
                GoalProjectionView(
                    maintenance: profile.maintenanceCalories,
                    goal: goalValue,
                    minimum: profile.minimumCalories
                )
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Profile")
        .fullScreenCover(isPresented: $isRedoingSetup, onDismiss: closeIfRedoSaved) {
            OnboardingView(isRedo: true)
        }
        .onChange(of: profile.goal) {
            profile.normalizePace()
        }
        .onChange(of: profile) {
            // New answers mean new calculated targets.
            adjustedGoal = nil
            adjustedProtein = nil
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    profileData = profile.data
                    dailyGoal = goalValue
                    proteinTarget = proteinValue
                    dismiss()
                }
            }
        }
    }
}

extension ProfileEditView {
    /// The step-by-step setup already saved new targets, so there's nothing left to do here.
    private func closeIfRedoSaved() {
        if profileData != profileDataBeforeRedo {
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
    }
}
