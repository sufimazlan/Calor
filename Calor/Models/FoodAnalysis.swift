//
//  FoodAnalysis.swift
//  Calor
//

import Foundation

/// The result of analysing a meal photo or description. Matches the JSON
/// schema sent to Claude (`ClaudeRequest.schema`), so the response decodes
/// straight into it.
struct FoodAnalysis: Codable {
    struct Item: Codable {
        var name: String
        var portion: String?
        var calories: Int
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?
        /// 1–10, see `HealthScore`.
        var healthScore: Int?

        enum CodingKeys: String, CodingKey {
            case name, portion, calories
            case proteinG = "protein_g"
            case carbsG = "carbs_g"
            case fatG = "fat_g"
            case healthScore = "health_score"
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

    /// Score for the whole meal, weighted by calories.
    var mealHealthScore: Int? {
        HealthScore.meal(items.map { (calories: $0.calories, score: $0.healthScore) })
    }
}

// Decoding is forgiving (in an extension, so the memberwise initialiser stays):
// whole numbers may arrive as 550.0, blank portions and notes become nil, and
// scores are kept within 1–10.
extension FoodAnalysis.Item {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let portion = try container.decodeIfPresent(String.self, forKey: .portion)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.portion = portion?.isEmpty == false ? portion : nil
        calories = max(0, Int((try container.decode(Double.self, forKey: .calories)).rounded()))
        proteinG = try container.decodeIfPresent(Double.self, forKey: .proteinG).map { max($0, 0) }
        carbsG = try container.decodeIfPresent(Double.self, forKey: .carbsG).map { max($0, 0) }
        fatG = try container.decodeIfPresent(Double.self, forKey: .fatG).map { max($0, 0) }
        healthScore = HealthScore.clamped(
            try container.decodeIfPresent(Double.self, forKey: .healthScore).map { Int($0.rounded()) })
    }
}

extension FoodAnalysis {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isFood = try container.decode(Bool.self, forKey: .isFood)
        items = try container.decode([Item].self, forKey: .items).filter { !$0.name.isEmpty }
        confidence = (try? container.decode(Confidence.self, forKey: .confidence)) ?? .medium
        let notes = try container.decodeIfPresent(String.self, forKey: .notes)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self.notes = notes?.isEmpty == false ? notes : nil
    }
}

/// An analysis plus what it cost, shown on the review screen.
struct AnalysisResult {
    var analysis: FoodAnalysis
    /// US dollars, or nil for demo results.
    var costUSD: Double?
    /// Model that answered, e.g. "Haiku 4.5". Nil for demo results.
    var modelName: String?
}
