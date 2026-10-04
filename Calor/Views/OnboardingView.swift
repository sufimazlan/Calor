//
//  OnboardingView.swift
//  Calor
//

import SwiftUI
import UIKit

/// First-launch questions that work out a daily calorie goal and protein target.
/// Shown until a profile is saved.
struct OnboardingView: View {
    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0

    @State private var profile = Profile()
    @State private var step = Step.welcome
    /// The user's tweak to the suggested goal on the last screen, if any.
    @State private var adjustedGoal: Int?

    private enum Step: Int, CaseIterable {
        case welcome, sex, birthYear, height, weight, activity, goal, result
    }

    private var goalValue: Int {
        adjustedGoal ?? profile.suggestedCalories
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                ProgressView(value: Double(step.rawValue), total: Double(Step.allCases.count - 1))
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
            }

            VStack(alignment: .leading, spacing: 20) {
                stepContent
                Spacer(minLength: 0)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .animation(.default, value: step)
        .onChange(of: profile.goal) {
            profile.normalizePace()
        }
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
            Text("Welcome to Calor")
                .font(.largeTitle.bold())
            Text("Answer a few quick questions and Calor will work out a daily calorie goal and protein target for you.")
                .font(.title3)
            Label("Takes about 30 seconds", systemImage: "clock")
                .foregroundStyle(.secondary)
            Label("Stays on this phone. Never sent to Claude.", systemImage: "lock")
                .foregroundStyle(.secondary)

        case .sex:
            question("What's your sex?", hint: "Men and women burn calories at slightly different rates.")
            ForEach(Sex.allCases) { sex in
                ChoiceCard(title: sex.title, isSelected: profile.sex == sex) {
                    profile.sex = sex
                }
            }

        case .birthYear:
            question("What year were you born?", hint: "You burn a little less each decade.")
            Picker("Birth year", selection: $profile.birthYear) {
                ForEach(Array(Profile.birthYearRange.reversed()), id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)

        case .height:
            question("How tall are you?")
            Picker("Height", selection: $profile.heightCm) {
                ForEach(Profile.heightRange, id: \.self) { cm in
                    Text("\(cm) cm").tag(cm)
                }
            }
            .pickerStyle(.wheel)

        case .weight:
            question("How much do you weigh?", hint: "You can update this later in Settings.")
            Picker("Weight", selection: $profile.weightKg) {
                ForEach(Profile.weightRange, id: \.self) { kg in
                    Text("\(kg) kg").tag(kg)
                }
            }
            .pickerStyle(.wheel)

        case .activity:
            question("How active are you?", hint: "Pick the closest match for a typical week.")
            ForEach(ActivityLevel.allCases) { level in
                ChoiceCard(title: level.title, detail: level.detail, isSelected: profile.activity == level) {
                    profile.activity = level
                }
            }

        case .goal:
            question("What's your goal?")
            ForEach(WeightGoal.allCases) { goal in
                ChoiceCard(title: goal.title, isSelected: profile.goal == goal) {
                    profile.goal = goal
                }
            }
            if profile.goal != .maintain {
                Text("How fast?")
                    .font(.headline)
                    .padding(.top, 8)
                Picker("Pace", selection: $profile.paceKgPerWeek) {
                    ForEach(profile.goal.paceOptions, id: \.self) { pace in
                        Text("\(pace.formatted()) kg/week").tag(pace)
                    }
                }
                .pickerStyle(.segmented)
                Text("Slower is easier to stick to.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

        case .result:
            resultContent
        }
    }

    @ViewBuilder
    private var resultContent: some View {
        Text("Your daily goal")
            .font(.title2.bold())
        Text("\(goalValue.formatted()) kcal")
            .font(.system(size: 52, weight: .bold))
            .monospacedDigit()
        Stepper("Adjust", value: Binding(
            get: { goalValue },
            set: { adjustedGoal = $0 }
        ), in: 1000...5000, step: 50)

        VStack(spacing: 10) {
            LabeledContent("To maintain your weight", value: "\(profile.maintenanceCalories.formatted()) kcal")
            if profile.goal != .maintain {
                LabeledContent(
                    "To \(profile.goal == .lose ? "lose" : "gain") \(profile.paceKgPerWeek.formatted()) kg/week",
                    value: "\(profile.dailyAdjustment > 0 ? "+" : "−")\(abs(profile.dailyAdjustment).formatted()) kcal"
                )
            }
            LabeledContent("Protein target", value: "\(profile.suggestedProteinG) g a day")
        }
        .padding()
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))

        if profile.isAtMinimum {
            Text("Raised to \(profile.minimumCalories.formatted()) kcal, the usual minimum without a doctor's supervision.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        Text("You can change these any time in Settings.")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func question(_ title: String, hint: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title.bold())
            if let hint {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Navigation

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                Button("Back") {
                    if let previous = Step(rawValue: step.rawValue - 1) {
                        step = previous
                    }
                }
                .buttonStyle(.bordered)
            }
            Button {
                goForward()
            } label: {
                Text(step == .result ? "Start using Calor" : "Continue")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .controlSize(.large)
        .padding(24)
    }

    private func goForward() {
        if let next = Step(rawValue: step.rawValue + 1) {
            if next == .result {
                adjustedGoal = nil
            }
            step = next
        } else {
            finish()
        }
    }

    private func finish() {
        dailyGoal = goalValue
        proteinTarget = profile.suggestedProteinG
        // Saved last: this switches the app from onboarding to the main tabs.
        profileData = profile.data
    }
}

/// A large tappable option with a checkmark.
private struct ChoiceCard: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding()
            .background(
                isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground),
                in: .rect(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
}
