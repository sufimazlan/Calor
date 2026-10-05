//
//  Settings.swift
//  Calor
//

/// Keys and defaults for values stored with `@AppStorage` (UserDefaults).
/// The Claude API key is not stored here; it goes in the Keychain (`KeychainStore`).
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

    /// Notifications 1 day and 1 hour before this install expires (free Apple ID: 7 days).
    static let reinstallRemindersEnabled = "reinstallRemindersEnabled"

    /// Automatic backup to a folder the user picks once (e.g. On My iPhone/Calor Backups).
    static let backupFolderBookmark = "backupFolderBookmark"
    /// Seconds since 1970 of the last successful backup. 0 means never.
    static let backupLastDate = "backupLastDate"
    /// Why the last backup failed, or empty.
    static let backupLastError = "backupLastError"
    static let backupIncludesPhotos = "backupIncludesPhotos"
    /// The Today screen's "turn on backup" card was dismissed.
    static let backupPromptDismissed = "backupPromptDismissed"

    // MARK: Water

    /// Daily water goal in glasses of `waterGlassML`.
    static let waterGoalGlasses = "waterGoalGlasses"
    static let defaultWaterGoal = 8
    static let waterGlassML = 250

    // MARK: Weight

    /// Monday-morning "weekly weigh-in" notification.
    static let weighInReminderEnabled = "weighInReminderEnabled"
    /// Seconds since 1970 until which the smart goal suggestion stays hidden.
    static let coachHiddenUntil = "coachHiddenUntil"

    // MARK: Claude photo analysis

    /// `ClaudeModel` raw value.
    static let aiModel = "aiModel"
    /// This phone's monthly spending limit in US dollars (at most `AIBudget.maxMonthlyLimit`).
    static let aiMonthlyLimitUSD = "aiMonthlyLimitUSD"
    /// Show the photo with a note field before analysing, instead of analysing at once.
    static let analysisAsksForNote = "analysisAsksForNote"
    /// Spending this month: "2026-10" and millionths of a dollar.
    static let aiSpendMonth = "aiSpendMonth"
    static let aiSpendMicros = "aiSpendMicros"
    static let aiCallsMonth = "aiCallsMonth"
    /// Analyses today: "2026-10-05" and the count.
    static let aiCallsDay = "aiCallsDay"
    static let aiCallsToday = "aiCallsToday"
    /// The API turned down the fallback option once, so it isn't sent again.
    static let aiFallbacksUnsupported = "aiFallbacksUnsupported"

    // MARK: Apple Health

    static let healthEnabled = "healthEnabled"
    /// Percent of workout calories added to the day's goal: 0, 50 or 100.
    static let healthWorkoutShare = "healthWorkoutShare"
    static let healthWritesWeight = "healthWritesWeight"
    static let healthReadsWeight = "healthReadsWeight"
    /// Seconds since 1970 of the newest weight imported from Health.
    static let healthLastWeightImport = "healthLastWeightImport"
}
