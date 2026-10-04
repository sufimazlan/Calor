//
//  Advice.swift
//  Calor
//

import Foundation

/// "What's next" tips for the Today screen. Worked out on the phone from
/// today's numbers, so they're free and work offline (no API call).
enum Advice {
    static func whatsNext(
        eaten: Int,
        goal: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        hasEntries: Bool,
        now: Date = .now
    ) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let remaining = goal - eaten

        guard hasEntries else {
            return hour < 11
                ? "Start the day by snapping your breakfast."
                : "Nothing logged yet today. Snap your next meal to start tracking."
        }

        var tip: String
        if remaining < 0 {
            tip = "You're \((-remaining).formatted()) kcal over today's goal. Keep the rest of today light: water, plain tea, or fruit if you're hungry."
        } else if remaining <= 150 {
            tip = "Almost at your goal, with \(remaining) kcal left. A sugar-free drink or a piece of fruit still fits."
        } else {
            switch hour {
            case ..<11:
                tip = "\(remaining.formatted()) kcal left today. That's about \((remaining / 2).formatted()) kcal each for lunch and dinner."
            case ..<16:
                tip = "\(remaining.formatted()) kcal left for the rest of today. Plan dinner around \(min(remaining, 700).formatted()) kcal."
            case ..<21:
                tip = "\(remaining.formatted()) kcal left for dinner and anything after."
            default:
                tip = "\(remaining.formatted()) kcal left. If you snack tonight, keep it under \(min(remaining, 300)) kcal."
            }
        }

        // Protein check, only once a fair amount has been eaten and macros were logged.
        let macroCalories = proteinG * 4 + carbsG * 4 + fatG * 9
        if eaten >= 800, macroCalories > 0, proteinG * 4 / macroCalories < 0.15 {
            tip += " Protein is low so far. Eggs, chicken, fish, tofu or tempeh would help at your next meal."
        }
        return tip
    }
}
