//
//  DataExport.swift
//  Calor
//

import Foundation
import SwiftData

/// "Export as CSV" in Settings: every meal, plus one row per day with totals,
/// water and weight.
enum DataExport {
    /// Writes the files to a temporary folder and returns them for the share sheet.
    static func makeFiles(context: ModelContext, now: Date = .now) throws -> [URL] {
        let entries = try context.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.timestamp)]))
        let weights = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))
        let water = try context.fetch(FetchDescriptor<WaterLog>())
        let calendar = Calendar.current

        let meals = entries.map { entry in
            CSVExport.MealRow(date: entry.timestamp, meal: entry.mealType.rawValue, name: entry.name,
                              portion: entry.portion, calories: entry.calories, proteinG: entry.proteinG,
                              carbsG: entry.carbsG, fatG: entry.fatG, healthScore: entry.healthScore,
                              source: entry.source.rawValue, isFavorite: entry.isFavorite, notes: entry.notes)
        }

        var days: [Date: CSVExport.DayRow] = [:]
        func row(for date: Date) -> CSVExport.DayRow {
            let day = calendar.startOfDay(for: date)
            return days[day] ?? CSVExport.DayRow(day: day, calories: 0, proteinG: 0, carbsG: 0, fatG: 0, mealCount: 0)
        }
        for entry in entries {
            var day = row(for: entry.timestamp)
            day.calories += entry.calories
            day.proteinG += entry.proteinG ?? 0
            day.carbsG += entry.carbsG ?? 0
            day.fatG += entry.fatG ?? 0
            day.mealCount += 1
            days[day.day] = day
        }
        for log in water where log.glasses > 0 {
            var day = row(for: log.day)
            day.waterGlasses = log.glasses
            days[day.day] = day
        }
        for weight in weights {
            // Sorted oldest first, so the day's last weigh-in wins.
            var day = row(for: weight.date)
            day.weightKg = weight.kg
            days[day.day] = day
        }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Calor export", isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = now.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        let mealsFile = folder.appendingPathComponent("Calor meals \(stamp).csv")
        let daysFile = folder.appendingPathComponent("Calor daily totals \(stamp).csv")
        try CSVExport.meals(meals).write(to: mealsFile, atomically: true, encoding: .utf8)
        try CSVExport.days(Array(days.values)).write(to: daysFile, atomically: true, encoding: .utf8)
        return [mealsFile, daysFile]
    }
}
