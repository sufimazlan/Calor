//
//  SettingsView.swift
//  Calor
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @AppStorage(SettingsKey.carbsTargetG) private var carbsTarget = 0
    @AppStorage(SettingsKey.fatTargetG) private var fatTarget = 0
    @AppStorage(SettingsKey.rolloverEnabled) private var rolloverEnabled = false
    @AppStorage(SettingsKey.remindersEnabled) private var remindersEnabled = false
    @AppStorage(SettingsKey.breakfastReminderMinutes) private var breakfastMinutes = MealReminders.all[0].defaultMinutes
    @AppStorage(SettingsKey.lunchReminderMinutes) private var lunchMinutes = MealReminders.all[1].defaultMinutes
    @AppStorage(SettingsKey.dinnerReminderMinutes) private var dinnerMinutes = MealReminders.all[2].defaultMinutes
    @State private var remindersBlocked = false
    @State private var backupFlow = BackupFlow()
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.avatarJPEG) private var avatarData: Data?
    @State private var isRedoingSetup = false

    private var profileSummary: String {
        guard let profile = Profile(data: profileData) else { return "Not set" }
        return "\(profile.age) · \(profile.heightText) · \(profile.weightText(profile.weightKg))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        ProfileEditView()
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(imageData: avatarData, name: userName, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userName.isEmpty ? "Edit profile" : userName)
                                Text(profileSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Button("Redo setup questions") {
                        isRedoingSetup = true
                    }
                } header: {
                    Text("Your profile")
                } footer: {
                    Text("Name, photo, weight, height, workouts, goal and diet. Update your weight now and then to keep the goal accurate.")
                }

                Section {
                    Stepper(value: $dailyGoal, in: 1000...5000, step: 50) {
                        LabeledContent("Daily goal", value: "\(dailyGoal.formatted()) kcal")
                    }
                    Stepper(value: $proteinTarget, in: 0...300, step: 5) {
                        LabeledContent("Protein target", value: proteinTarget > 0 ? "\(proteinTarget) g" : "Off")
                    }
                    Stepper(value: macroBinding($carbsTarget, auto: autoMacros.carbsG), in: 0...600, step: 5) {
                        LabeledContent("Carbs target", value: macroText(carbsTarget, auto: autoMacros.carbsG))
                    }
                    Stepper(value: macroBinding($fatTarget, auto: autoMacros.fatG), in: 0...300, step: 5) {
                        LabeledContent("Fat target", value: macroText(fatTarget, auto: autoMacros.fatG))
                    }
                    if carbsTarget > 0 || fatTarget > 0 {
                        Button("Work out carbs and fat automatically") {
                            carbsTarget = 0
                            fatTarget = 0
                        }
                    }
                } header: {
                    Text("Targets")
                } footer: {
                    Text("Calculated from your profile. Fine-tune them here. Automatic carbs and fat: 30% of calories from fat, carbs for the rest. Each phone keeps its own.")
                }

                Section {
                    Toggle("Roll over unused calories", isOn: $rolloverEnabled)
                } footer: {
                    Text("Up to \(SettingsKey.maxRollover) kcal left over yesterday is added to today's goal.")
                }

                Section {
                    Toggle("Meal reminders", isOn: $remindersEnabled)
                    if remindersEnabled {
                        DatePicker("Breakfast", selection: timeBinding($breakfastMinutes), displayedComponents: .hourAndMinute)
                        DatePicker("Lunch", selection: timeBinding($lunchMinutes), displayedComponents: .hourAndMinute)
                        DatePicker("Dinner", selection: timeBinding($dinnerMinutes), displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    if remindersBlocked {
                        Text("Notifications are turned off for Calor. Turn them on in the iPhone Settings app → Notifications → Calor.")
                    } else {
                        Text("A daily nudge to snap your meal.")
                    }
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

                BackupSettingsSection(flow: backupFlow)
                InstallSettingsSection()

                Section {
                    LabeledContent("Mode", value: "Demo")
                } header: {
                    Text("Photo analysis")
                } footer: {
                    Text("Photos get sample results for now. Real Claude analysis starts once an API key is added here.")
                }
            }
            .navigationTitle("Settings")
            .backupFlowPresenter(backupFlow)
            .onChange(of: remindersEnabled) { _, isOn in
                Task {
                    if isOn {
                        let granted = await MealReminders.requestPermission()
                        remindersBlocked = !granted
                        if !granted {
                            remindersEnabled = false
                        }
                    }
                    await MealReminders.reschedule()
                }
            }
            .onChange(of: [breakfastMinutes, lunchMinutes, dinnerMinutes]) {
                Task { await MealReminders.reschedule() }
            }
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

extension SettingsView {
    private var autoMacros: MacroTargets {
        MacroTargets(calorieGoal: dailyGoal, proteinTargetG: proteinTarget)
    }

    /// Shows the automatic value until the user changes it.
    private func macroBinding(_ stored: Binding<Int>, auto: Int) -> Binding<Int> {
        Binding(get: { stored.wrappedValue > 0 ? stored.wrappedValue : auto },
                set: { stored.wrappedValue = $0 })
    }

    private func macroText(_ stored: Int, auto: Int) -> String {
        stored > 0 ? "\(stored) g" : "\(auto) g (auto)"
    }

    /// Minutes after midnight as a time of day for a DatePicker.
    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: minutes.wrappedValue / 60, minute: minutes.wrappedValue % 60,
                                      second: 0, of: .now) ?? .now
            },
            set: { date in
                let time = Calendar.current.dateComponents([.hour, .minute], from: date)
                minutes.wrappedValue = (time.hour ?? 0) * 60 + (time.minute ?? 0)
            }
        )
    }
}

#Preview {
    SettingsView()
}
