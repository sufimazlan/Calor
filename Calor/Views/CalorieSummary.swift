//
//  CalorieSummary.swift
//  Calor
//

import SwiftUI

/// Progress ring showing calories left (or over) for the day, plus eaten and goal.
struct CalorieSummary: View {
    let eaten: Int
    let goal: Int

    private var remaining: Int { goal - eaten }
    private var isOver: Bool { remaining < 0 }
    private var progress: Double { goal > 0 ? Double(eaten) / Double(goal) : 0 }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(isOver ? Color.orange : Color.accentColor,
                            style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.default, value: progress)
                VStack(spacing: 2) {
                    Text(abs(remaining), format: .number)
                        .font(.largeTitle.bold())
                        .monospacedDigit()
                    Text(isOver ? "kcal over" : "kcal left")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180)

            HStack(spacing: 40) {
                stat("Eaten", value: eaten)
                stat("Goal", value: goal)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }

    private func stat(_ title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.headline)
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    VStack(spacing: 40) {
        CalorieSummary(eaten: 1350, goal: 2000)
        CalorieSummary(eaten: 2250, goal: 2000)
    }
}
