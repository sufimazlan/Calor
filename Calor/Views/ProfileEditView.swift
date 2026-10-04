//
//  ProfileEditView.swift
//  Calor
//

import SwiftUI
import PhotosUI
import UIKit

/// Edit the profile from Settings. Saving recalculates the calorie goal and protein target.
struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0

    @AppStorage(SettingsKey.userName) private var savedName = ""
    @AppStorage(SettingsKey.avatarJPEG) private var savedAvatar: Data?

    @State private var profile: Profile
    @State private var name: String
    @State private var avatarData: Data?
    @State private var photoItem: PhotosPickerItem?
    @State private var isRedoingSetup = false
    /// The user's tweaks to the calculated targets, if any.
    @State private var adjustedGoal: Int?
    @State private var adjustedProtein: Int?
    /// Saved profile when the step-by-step setup was opened, to tell if it was saved.
    @State private var profileDataBeforeRedo: Data?

    init() {
        let saved = Profile(data: UserDefaults.standard.data(forKey: SettingsKey.profile))
        _profile = State(initialValue: saved ?? Profile())
        _name = State(initialValue: UserDefaults.standard.string(forKey: SettingsKey.userName) ?? "")
        _avatarData = State(initialValue: UserDefaults.standard.data(forKey: SettingsKey.avatarJPEG))
    }

    private var goalValue: Int {
        adjustedGoal ?? profile.suggestedCalories
    }

    private var proteinValue: Int {
        adjustedProtein ?? profile.suggestedProteinG
    }

    var body: some View {
        Form {
            Section("You") {
                HStack(spacing: 16) {
                    AvatarView(imageData: avatarData, name: name, size: 72)
                    VStack(alignment: .leading, spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Text(avatarData == nil ? "Add photo" : "Change photo")
                        }
                        if avatarData != nil {
                            Button("Remove photo", role: .destructive) {
                                avatarData = nil
                            }
                        }
                    }
                    // Several buttons in one Form row each need their own tap area.
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 4)
                TextField("Your name", text: $name)
                    .textContentType(.name)
            }

            Section {
                Button("Answer step by step (like the first setup)", systemImage: "list.number") {
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
                DatePicker("Birthday", selection: $profile.birthDate, in: Profile.birthDateRange,
                           displayedComponents: .date)
                Picker("Height", selection: $profile.heightCm) {
                    ForEach(Profile.heightRange, id: \.self) { cm in
                        Text("\(cm) cm").tag(cm)
                    }
                }
                Stepper(value: $profile.weightKg, in: Profile.weightRange, step: 0.5) {
                    LabeledContent("Weight", value: profile.weightText(profile.weightKg))
                }
            }

            Section("Goal") {
                Picker("Workouts", selection: $profile.activity) {
                    ForEach(ActivityLevel.choices) { level in
                        Text(level.title).tag(level)
                    }
                    if profile.activity == .light {
                        Text(ActivityLevel.light.title).tag(ActivityLevel.light)
                    }
                }
                Picker("Goal", selection: $profile.goal) {
                    ForEach(WeightGoal.allCases) { goal in
                        Text(goal.title).tag(goal)
                    }
                }
                if profile.goal != .maintain {
                    Stepper(value: $profile.targetWeightKg, in: Profile.weightRange, step: 0.5) {
                        LabeledContent("Target weight", value: profile.weightText(profile.targetWeightKg))
                    }
                    Stepper(value: $profile.paceKgPerWeek, in: profile.goal.paceRange, step: 0.1) {
                        LabeledContent("Pace", value: "\(profile.weightText(profile.paceKgPerWeek))/week")
                    }
                }
                Picker("Diet", selection: $profile.diet) {
                    ForEach(DietType.allCases) { diet in
                        Text(diet.title).tag(diet)
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
            profile.normalize()
        }
        .onChange(of: profile.weightKg) {
            profile.normalize()
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    avatarData = ImageProcessing.avatarJPEG(from: image)
                }
                photoItem = nil
            }
        }
        .onChange(of: profile) {
            // New answers mean new calculated targets.
            adjustedGoal = nil
            adjustedProtein = nil
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    savedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    savedAvatar = avatarData
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
