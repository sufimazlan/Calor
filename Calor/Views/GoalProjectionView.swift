//
//  GoalProjectionView.swift
//  Calor
//

import SwiftUI

/// How fast weight would change at a given daily goal, using
/// about 7,700 kcal per kg of body weight.
struct GoalProjectionView: View {
    let maintenance: Int
    let goal: Int
    let minimum: Int

    /// Negative means eating less than you burn.
    private var dailyChange: Int { goal - maintenance }
    private var isLosing: Bool { dailyChange < 0 }
    private var kgPerWeek: Double { Double(abs(dailyChange)) * 7 / 7700 }
    private var daysPerKg: Int { Int((7700 / Double(max(abs(dailyChange), 1))).rounded()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("With \(goal.formatted()) kcal a day")
                .font(.headline)

            if abs(dailyChange) < 50 {
                Text("You'd stay about the same weight.")
                    .foregroundStyle(.secondary)
            } else {
                LabeledContent(isLosing ? "Daily deficit" : "Daily surplus",
                               value: "\(abs(dailyChange).formatted()) kcal")
                LabeledContent(isLosing ? "Lose 1 kg every" : "Gain 1 kg every",
                               value: "\(daysPerKg) days")
                LabeledContent("Per week", value: kg(kgPerWeek))
                LabeledContent("Per month", value: kg(kgPerWeek * 30 / 7))
                LabeledContent("In 3 months", value: kg(kgPerWeek * 13))
            }

            if goal < minimum {
                warning("Below \(minimum.formatted()) kcal, the usual minimum without a doctor's supervision. Eating this little often means losing muscle, and it's hard to keep up.")
            } else if isLosing && kgPerWeek > 1 {
                warning("Faster than 1 kg a week is hard to keep up.")
            }

            Text("Estimates. Real results vary, and the first week often drops faster from water weight.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .monospacedDigit()
    }

    private func kg(_ value: Double) -> String {
        let sign = isLosing ? "−" : "+"
        return "\(sign)\(value.formatted(.number.precision(.fractionLength(1)))) kg"
    }

    private func warning(_ text: String) -> some View {
        Label {
            Text(text)
                .font(.footnote)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        GoalProjectionView(maintenance: 2160, goal: 1610, minimum: 1500)
        GoalProjectionView(maintenance: 2160, goal: 1160, minimum: 1500)
    }
    .padding()
}
