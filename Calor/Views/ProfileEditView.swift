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

    init() {
        let saved = Profile(data: UserDefaults.standard.data(forKey: SettingsKey.profile))
        _profile = State(initialValue: saved ?? Profile())
    }

    var body: some View {
        Form {
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
                LabeledContent("Daily goal", value: "\(profile.suggestedCalories.formatted()) kcal")
                LabeledContent("Protein target", value: "\(profile.suggestedProteinG) g a day")
            } header: {
                Text("New targets")
            } footer: {
                Text("Saving replaces your current goal (\(dailyGoal.formatted()) kcal) and protein target.")
            }
        }
        .navigationTitle("Profile")
        .onChange(of: profile.goal) {
            profile.normalizePace()
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    profileData = profile.data
                    dailyGoal = profile.suggestedCalories
                    proteinTarget = profile.suggestedProteinG
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileEditView()
    }
}
