//
//  WidgetSync.swift
//  Calor
//

import Foundation
import WidgetKit

/// Shares today's numbers with the home screen widget. Both read and write the
/// same UserDefaults in the app group, which the widget extension can open.
enum WidgetSync {
    static let appGroup = "group.com.sufimazlan.Calor"
    static let snapshotKey = "widgetSnapshot"
    /// Counters that start again from zero each day.
    private static let dailyKeys = ["eaten", "protein", "water"]

    /// Merges these values into today's snapshot and refreshes the widget if anything changed.
    /// Keys: eaten, goal, protein, proteinTarget, water, waterGoal, streak.
    static func update(_ values: [String: Int], now: Date = .now) {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return }
        let stored = defaults.dictionary(forKey: snapshotKey) as? [String: Int] ?? [:]
        var snapshot = stored
        let today = dayNumber(now)
        if snapshot["day"] != today {
            for key in dailyKeys {
                snapshot[key] = 0
            }
            snapshot["day"] = today
        }
        snapshot.merge(values) { _, new in new }
        guard snapshot != stored else { return }
        defaults.set(snapshot, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// 2026-10-05 as 20261005.
    static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}
