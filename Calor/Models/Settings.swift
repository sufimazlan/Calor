//
//  Settings.swift
//  Calor
//

/// Keys and defaults for values stored with `@AppStorage` (UserDefaults).
/// The Claude API key is not stored here; it goes in the Keychain (milestone 3).
enum SettingsKey {
    static let dailyGoalKcal = "dailyGoalKcal"
    static let defaultDailyGoal = 2000
}
