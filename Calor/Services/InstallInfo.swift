//
//  InstallInfo.swift
//  Calor
//

import Foundation
import UserNotifications

/// When this install of Calor stops opening.
///
/// Apps installed from Xcode with a free Apple ID are signed with a
/// provisioning profile that expires after 7 days. Xcode copies that profile
/// into the app as `embedded.mobileprovision`; its plist part holds the
/// `ExpirationDate`. In the simulator there is no profile, so this is nil.
enum InstallInfo {
    static let expirationDate: Date? = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }

        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any]
        return plist?["ExpirationDate"] as? Date
    }()

    /// True in the last 24 hours before the install expires.
    static var expiresSoon: Bool {
        guard let expirationDate else { return false }
        return expirationDate.timeIntervalSinceNow < 24 * 60 * 60
    }
}

/// "Reinstall Calor from Xcode" notifications, 1 day and 1 hour before the install expires.
enum ReinstallReminders {
    private static let identifiers = ["reinstall-reminder-1-day", "reinstall-reminder-1-hour"]

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: SettingsKey.reinstallRemindersEnabled) as? Bool ?? true
    }

    /// Replaces any scheduled reminders. Call when the app opens: a reinstall
    /// from Xcode may bring a new expiry date.
    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        guard isEnabled, let expiry = InstallInfo.expirationDate, expiry > .now else { return }

        if await center.notificationSettings().authorizationStatus == .notDetermined {
            // Don't interrupt first-launch setup; it has its own reminders screen.
            guard UserDefaults.standard.data(forKey: SettingsKey.profile) != nil else { return }
            _ = await MealReminders.requestPermission()
        }

        let reminders: [(id: String, before: TimeInterval, when: String)] = [
            (identifiers[0], 24 * 60 * 60, "in 1 day"),
            (identifiers[1], 60 * 60, "in 1 hour"),
        ]
        for reminder in reminders {
            let fireDate = expiry.addingTimeInterval(-reminder.before)
            guard fireDate > .now else { continue }

            let content = UNMutableNotificationContent()
            content.title = "Reinstall Calor from Xcode"
            content.body = "Calor stops opening \(reminder.when) (\(expiry.formatted(date: .abbreviated, time: .shortened))). Open Xcode on the Mac and press ⌘R with this iPhone nearby. Your meals are kept."
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: fireDate.timeIntervalSinceNow, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }
}
