//
//  MealReminders.swift
//  Calor
//

import Foundation
import UserNotifications

/// Daily "time to log" notifications for breakfast, lunch and dinner.
/// Sent by the phone itself, so they're free and work offline.
enum MealReminders {
    struct Reminder {
        let meal: MealType
        let key: String
        let defaultMinutes: Int

        var identifier: String { "meal-reminder-\(meal.rawValue)" }
    }

    static let all: [Reminder] = [
        Reminder(meal: .breakfast, key: SettingsKey.breakfastReminderMinutes, defaultMinutes: 8 * 60),
        Reminder(meal: .lunch, key: SettingsKey.lunchReminderMinutes, defaultMinutes: 12 * 60 + 30),
        Reminder(meal: .dinner, key: SettingsKey.dinnerReminderMinutes, defaultMinutes: 19 * 60),
    ]

    /// Asks iOS for permission. Returns false if the user says no.
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func minutes(for reminder: Reminder) -> Int {
        UserDefaults.standard.object(forKey: reminder.key) as? Int ?? reminder.defaultMinutes
    }

    /// After restoring a backup: if the restored settings turn reminders on, ask for
    /// permission (a fresh install hasn't been asked yet), then schedule them.
    static func applyRestoredSettings() async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: SettingsKey.remindersEnabled), !(await requestPermission()) {
            defaults.set(false, forKey: SettingsKey.remindersEnabled)
        }
        await reschedule()
    }

    /// Replaces any scheduled reminders with the current settings.
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: all.map(\.identifier))
        guard UserDefaults.standard.bool(forKey: SettingsKey.remindersEnabled) else { return }

        for reminder in all {
            let content = UNMutableNotificationContent()
            content.title = "Time to log \(reminder.meal.rawValue)?"
            content.body = "Snap your \(reminder.meal.rawValue) so Calor can keep your day on track."
            content.sound = .default

            let minutes = minutes(for: reminder)
            var time = DateComponents()
            time.hour = minutes / 60
            time.minute = minutes % 60
            let trigger = UNCalendarNotificationTrigger(dateMatching: time, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: reminder.identifier, content: content, trigger: trigger))
        }
    }
}
