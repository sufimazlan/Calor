//
//  WaterLog.swift
//  Calor
//

import Foundation
import SwiftData

/// Glasses of water drunk on one day (one record per day).
@Model
final class WaterLog {
    /// Start of the day, in the phone's time zone.
    var day: Date
    var glasses: Int

    init(day: Date, glasses: Int) {
        self.day = day
        self.glasses = glasses
    }
}
