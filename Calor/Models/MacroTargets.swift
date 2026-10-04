//
//  MacroTargets.swift
//  Calor
//

/// Daily gram targets for each macro, derived from the calorie goal:
/// protein from the profile, 30% of calories from fat, and carbs for the rest.
struct MacroTargets {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    init(calorieGoal: Int, proteinTargetG: Int) {
        // Without a protein target, assume 25% of calories from protein.
        let protein = proteinTargetG > 0 ? proteinTargetG : Int(Double(calorieGoal) * 0.25 / 4)
        let fat = Int((Double(calorieGoal) * 0.30 / 9).rounded())
        proteinG = protein
        fatG = fat
        carbsG = max(0, (calorieGoal - protein * 4 - fat * 9) / 4)
    }
}
