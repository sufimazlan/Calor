//
//  FoodEntry.swift
//  Calor
//

import Foundation
import SwiftData

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

enum EntrySource: String {
    case manual, photo
}

enum Confidence: String, Codable {
    case low, medium, high
}

@Model
final class FoodEntry {
    var id: UUID
    /// When the food was eaten.
    var timestamp: Date
    var name: String
    var portion: String?
    var calories: Int
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?
    var notes: String?
    /// Small JPEG of the meal photo (photo entries only).
    @Attribute(.externalStorage) var thumbnail: Data?

    // Enums are stored as plain strings so the database stays simple.
    // Use `mealType`, `source` and `confidence` below instead of these.
    var mealTypeRaw: String
    var sourceRaw: String
    var confidenceRaw: String?

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    var source: EntrySource {
        get { EntrySource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var confidence: Confidence? {
        get { confidenceRaw.flatMap(Confidence.init(rawValue:)) }
        set { confidenceRaw = newValue?.rawValue }
    }

    init(
        timestamp: Date = .now,
        mealType: MealType,
        name: String,
        portion: String? = nil,
        calories: Int,
        proteinG: Double? = nil,
        carbsG: Double? = nil,
        fatG: Double? = nil,
        source: EntrySource = .manual,
        confidence: Confidence? = nil,
        thumbnail: Data? = nil,
        notes: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.name = name
        self.portion = portion
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.notes = notes
        self.thumbnail = thumbnail
        self.mealTypeRaw = mealType.rawValue
        self.sourceRaw = source.rawValue
        self.confidenceRaw = confidence?.rawValue
    }
}
