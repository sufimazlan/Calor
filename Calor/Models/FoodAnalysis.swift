//
//  FoodAnalysis.swift
//  Calor
//

import Foundation

/// The result of analysing a meal photo. Matches the JSON in PRD section 8,
/// so the real Claude response can be decoded straight into it.
struct FoodAnalysis: Codable {
    struct Item: Codable {
        var name: String
        var portion: String?
        var calories: Int
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?

        enum CodingKeys: String, CodingKey {
            case name, portion, calories
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
        }
    }

    var isFood: Bool
    var items: [Item]
    var confidence: Confidence
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case isFood = "is_food"
        case items, confidence, notes
    }
}
