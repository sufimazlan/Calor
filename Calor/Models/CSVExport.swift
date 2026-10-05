//
//  CSVExport.swift
//  Calor
//

import Foundation

/// Builds the CSV files for "Export as CSV" in Settings. They open in
/// Numbers, Excel and Google Sheets.
enum CSVExport {
    struct MealRow {
        var date: Date
        var meal: String
        var name: String
        var portion: String?
        var calories: Int
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?
        var healthScore: Int?
        var source: String
        var isFavorite: Bool
        var notes: String?
    }

    struct DayRow {
        var day: Date
        var calories: Int
        var proteinG: Double
        var carbsG: Double
        var fatG: Double
        var mealCount: Int
        var waterGlasses: Int?
        var weightKg: Double?
    }

    static func meals(_ rows: [MealRow], timeZone: TimeZone = .current) -> String {
        let header = ["date", "time", "meal", "food", "portion", "calories", "protein_g", "carbs_g", "fat_g",
                      "health_score", "source", "favourite", "notes"]
        let lines = rows.sorted { $0.date < $1.date }.map { row in
            [
                dayText(row.date, timeZone: timeZone),
                timeText(row.date, timeZone: timeZone),
                row.meal,
                row.name,
                row.portion ?? "",
                String(row.calories),
                number(row.proteinG),
                number(row.carbsG),
                number(row.fatG),
                row.healthScore.map(String.init) ?? "",
                row.source,
                row.isFavorite ? "yes" : "",
                row.notes ?? "",
            ]
        }
        return document(header: header, rows: lines)
    }

    static func days(_ rows: [DayRow], timeZone: TimeZone = .current) -> String {
        let header = ["date", "calories", "protein_g", "carbs_g", "fat_g", "meals", "water_glasses", "weight_kg"]
        let lines = rows.sorted { $0.day < $1.day }.map { row in
            [
                dayText(row.day, timeZone: timeZone),
                String(row.calories),
                number(row.proteinG),
                number(row.carbsG),
                number(row.fatG),
                String(row.mealCount),
                row.waterGlasses.map(String.init) ?? "",
                number(row.weightKg),
            ]
        }
        return document(header: header, rows: lines)
    }

    // MARK: - Formatting

    /// RFC 4180: fields with a comma, quote or line break go in quotes, with quotes doubled.
    static func escape(_ field: String) -> String {
        guard field.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Starts with a byte order mark so Excel reads accents and emoji correctly.
    static func document(header: [String], rows: [[String]]) -> String {
        "\u{FEFF}" + ([header] + rows)
            .map { row in row.map { escape($0) }.joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }

    /// Always a dot for decimals, whatever the phone's region, so spreadsheets read it as a number.
    static func number(_ value: Double?) -> String {
        guard let value else { return "" }
        let rounded = (value * 10).rounded() / 10
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static func dayText(_ date: Date, timeZone: TimeZone) -> String {
        formatter("yyyy-MM-dd", timeZone: timeZone).string(from: date)
    }

    private static func timeText(_ date: Date, timeZone: TimeZone) -> String {
        formatter("HH:mm", timeZone: timeZone).string(from: date)
    }

    private static func formatter(_ format: String, timeZone: TimeZone) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }
}
