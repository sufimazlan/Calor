//
//  Settings.swift
//  Calor
//

/// Keys and defaults for values stored with `@AppStorage` (UserDefaults).
/// The Claude API key is not stored here; it goes in the Keychain (milestone 3).
enum SettingsKey {
    static let dailyGoalKcal = "dailyGoalKcal"
    static let defaultDailyGoal = 2000

    /// Grams per day. 0 means no target set.
    static let proteinTargetG = "proteinTargetG"
    /// Grams per day. 0 means worked out from the calorie goal.
    static let carbsTargetG = "carbsTargetG"
    static let fatTargetG = "fatTargetG"

    /// `Profile` encoded as JSON. Missing until onboarding is finished.
    static let profile = "profile"

    /// Shown with the avatar at the top of Today. Optional.
    static let userName = "userName"

    /// Small JPEG (about 300 px) of the user's profile photo. Optional.
    static let avatarJPEG = "avatarJPEG"

    /// Adds yesterday's unused calories (up to `maxRollover`) to today's goal.
    static let rolloverEnabled = "rolloverEnabled"
    static let maxRollover = 200

    /// Daily "time to log" notifications. Times are minutes after midnight.
    static let remindersEnabled = "remindersEnabled"
    static let breakfastReminderMinutes = "breakfastReminderMinutes"
    static let lunchReminderMinutes = "lunchReminderMinutes"
    static let dinnerReminderMinutes = "dinnerReminderMinutes"
}
