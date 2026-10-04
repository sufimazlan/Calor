//
//  MacroProgressView.swift
//  Calor
//

import SwiftUI

/// Protein, carbs and fat eaten against their daily targets.
struct MacroProgressView: View {
    let proteinG: Double
    let carbsG: Double
    let fatG: Double
    let targets: MacroTargets

    var body: some View {
        VStack(spacing: 12) {
            row("Protein", grams: proteinG, target: targets.proteinG)
            row("Carbs", grams: carbsG, target: targets.carbsG)
            row("Fat", grams: fatG, target: targets.fatG)
        }
        .padding(.vertical, 4)
    }

    private func row(_ name: String, grams: Double, target: Int) -> some View {
        let isOver = target > 0 && grams > Double(target) * 1.1
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                Spacer()
                Text("\(Int(grams.rounded())) / \(target) g\(isOver ? " · over" : "")")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.subheadline)
            ProgressView(value: min(grams / Double(max(target, 1)), 1))
                .tint(isOver ? .orange : .accentColor)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    List {
        MacroProgressView(proteinG: 62, carbsG: 140, fatG: 55,
                          targets: MacroTargets(calorieGoal: 1610, proteinTargetG: 144))
    }
}
