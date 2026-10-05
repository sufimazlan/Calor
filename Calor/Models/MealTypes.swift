//
//  MealTypes.swift
//  Calor
//

import Foundation

enum MealType: String, CaseIterable, Identifiable {
    case breakfast, lunch, dinner, snack

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    /// The meal people usually eat at this time of day, used as the default for new entries.
    static func suggested(for date: Date = .now) -> MealType {
        switch Calendar.current.component(.hour, from: date) {
        case 4..<11: .breakfast
        case 11..<15: .lunch
        case 15..<18: .snack
        case 18..<22: .dinner
        default: .snack
        }
    }
}

/// How an entry was logged.
enum EntrySource: String {
    /// Typed in by hand.
    case manual
    /// Analysed from a meal photo.
    case photo
    /// Analysed from a description in words.
    case text
}

enum Confidence: String, Codable {
    case low, medium, high
}

/// Health score of a food, from 1 (mostly sugar, fried or refined) to 10 (very nutritious).
enum HealthScore {
    static let range = 1...10

    static func clamped(_ score: Int?) -> Int? {
        score.map { min(max($0, range.lowerBound), range.upperBound) }
    }

    /// The meal's score: item scores weighted by calories, so a big plate of rice
    /// counts more than a squeeze of lime. Items without a score are left out.
    static func meal(_ items: [(calories: Int, score: Int?)]) -> Int? {
        let scored = items.compactMap { item in item.score.map { (calories: max(item.calories, 1), score: $0) } }
        guard !scored.isEmpty else { return nil }
        let weight = scored.reduce(0) { $0 + $1.calories }
        let total = scored.reduce(0) { $0 + $1.calories * $1.score }
        return clamped(Int((Double(total) / Double(weight)).rounded()))
    }

    static func label(_ score: Int) -> String {
        switch score {
        case 8...: "Great"
        case 6...7: "Good"
        case 4...5: "Fair"
        default: "Poor"
        }
    }
}
