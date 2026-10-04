//
//  MacroTargets.swift
//  Calor
//

/// Daily gram targets for each macro. By default they come from the calorie goal:
/// protein from the profile, 30% of calories from fat, and carbs for the rest.
/// Carbs and fat can be set by hand (0 means automatic).
struct MacroTargets {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    init(calorieGoal: Int, proteinTargetG: Int, carbsTargetG: Int = 0, fatTargetG: Int = 0) {
        // Without a protein target, assume 25% of calories from protein.
        let protein = proteinTargetG > 0 ? proteinTargetG : Int(Double(calorieGoal) * 0.25 / 4)
        let fat = fatTargetG > 0 ? fatTargetG : Int((Double(calorieGoal) * 0.30 / 9).rounded())
        proteinG = protein
        fatG = fat
        carbsG = carbsTargetG > 0 ? carbsTargetG : max(0, (calorieGoal - protein * 4 - fat * 9) / 4)
    }
}
