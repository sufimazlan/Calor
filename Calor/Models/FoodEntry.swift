//
//  FoodEntry.swift
//  Calor
//

import Foundation
import SwiftData

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
    /// Starred, so it shows in Favourites on the Add screen.
    var isFavorite: Bool = false
    /// 1–10 from the photo analysis (see `HealthScore`). Nil for entries typed in by hand.
    var healthScore: Int?

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
        notes: String? = nil,
        healthScore: Int? = nil
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
        self.healthScore = healthScore
        self.mealTypeRaw = mealType.rawValue
        self.sourceRaw = source.rawValue
        self.confidenceRaw = confidence?.rawValue
    }

    /// The same food logged again ("Log again", "Copy to today"). The copy is a new
    /// entry with its own id; it isn't a favourite itself.
    func duplicate(at date: Date = .now, mealType: MealType? = nil) -> FoodEntry {
        FoodEntry(
            timestamp: date,
            mealType: mealType ?? self.mealType,
            name: name,
            portion: portion,
            calories: calories,
            proteinG: proteinG,
            carbsG: carbsG,
            fatG: fatG,
            source: source,
            confidence: confidence,
            thumbnail: thumbnail,
            notes: notes,
            healthScore: healthScore
        )
    }

    /// Name used to group the same food, e.g. in Recent and Favourites.
    var matchKey: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
