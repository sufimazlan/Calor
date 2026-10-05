//
//  WeightEntry.swift
//  Calor
//

import Foundation
import SwiftData

enum WeightSource: String {
    /// Logged with "Log weight".
    case manual
    /// The weight entered in setup or the profile.
    case profile
    /// Imported from Apple Health.
    case health
}

/// One weigh-in. The newest one is also the profile's current weight,
/// which keeps the calorie maths up to date.
@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var kg: Double
    var sourceRaw: String

    var source: WeightSource {
        get { WeightSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(date: Date = .now, kg: Double, source: WeightSource = .manual) {
        self.id = UUID()
        self.date = date
        self.kg = kg
        self.sourceRaw = source.rawValue
    }
}
