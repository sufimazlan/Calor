//
//  SettingsView.swift
//  Calor
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @State private var isRedoingSetup = false

    private var profileSummary: String {
        guard let profile = Profile(data: profileData) else { return "Not set" }
        return "\(profile.age) · \(profile.heightCm) cm · \(profile.weightKg) kg"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        LabeledContent("Edit profile", value: profileSummary)
                    }
                    Button("Redo setup questions") {
                        isRedoingSetup = true
                    }
                } header: {
                    Text("Your profile")
                } footer: {
                    Text("Weight, height, activity and goal. Update your weight now and then to keep the goal accurate.")
                }

                Section {
                    Stepper(value: $dailyGoal, in: 1000...5000, step: 50) {
                        LabeledContent("Daily goal", value: "\(dailyGoal.formatted()) kcal")
                    }
                    Stepper(value: $proteinTarget, in: 0...300, step: 5) {
                        LabeledContent("Protein target", value: proteinTarget > 0 ? "\(proteinTarget) g" : "Off")
                    }
                } header: {
                    Text("Targets")
                } footer: {
                    Text("Calculated from your profile. Fine-tune them here. Each phone keeps its own.")
                }

                if let profile = Profile(data: profileData) {
                    Section {
                        GoalProjectionView(
                            maintenance: profile.maintenanceCalories,
                            goal: dailyGoal,
                            minimum: profile.minimumCalories
                        )
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    LabeledContent("Mode", value: "Demo")
                } header: {
                    Text("Photo analysis")
                } footer: {
                    Text("Photos get sample results for now. Real Claude analysis starts once an API key is added here.")
                }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $isRedoingSetup) {
                OnboardingView(isRedo: true)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
