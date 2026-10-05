//
//  CalorWidget.swift
//  CalorWidget
//

import Foundation
import SwiftUI
import WidgetKit

/// Today's numbers as the Calor app last saved them in the shared app group
/// (see `WidgetSync` in the app).
struct CalorEntry: TimelineEntry {
    let date: Date
    let eaten: Int
    let goal: Int
    let protein: Int
    let proteinTarget: Int
    let water: Int
    let waterGoal: Int
    let streak: Int
    /// False until the app has saved its first numbers.
    let hasData: Bool

    var remaining: Int { goal - eaten }
    var progress: Double { goal > 0 ? min(Double(eaten) / Double(goal), 1) : 0 }

    static let sample = CalorEntry(date: .now, eaten: 1_150, goal: 1_800, protein: 70, proteinTarget: 110,
                                   water: 5, waterGoal: 8, streak: 6, hasData: true)

    /// Reads the saved numbers. On a later day than they were saved, today's
    /// counters start at zero.
    static func load(for date: Date) -> CalorEntry {
        let defaults = UserDefaults(suiteName: "group.com.sufimazlan.Calor")
        guard let snapshot = defaults?.dictionary(forKey: "widgetSnapshot") as? [String: Int],
              let goal = snapshot["goal"] else {
            return CalorEntry(date: date, eaten: 0, goal: 0, protein: 0, proteinTarget: 0, water: 0, waterGoal: 0,
                              streak: 0, hasData: false)
        }
        let isSameDay = snapshot["day"] == dayNumber(date)
        func today(_ key: String) -> Int {
            isSameDay ? snapshot[key] ?? 0 : 0
        }
        return CalorEntry(date: date, eaten: today("eaten"), goal: goal, protein: today("protein"),
                          proteinTarget: snapshot["proteinTarget"] ?? 0, water: today("water"),
                          waterGoal: snapshot["waterGoal"] ?? 8, streak: snapshot["streak"] ?? 0, hasData: true)
    }

    /// 2026-10-05 as 20261005, the same as the app.
    static func dayNumber(_ date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (parts.year ?? 0) * 10000 + (parts.month ?? 0) * 100 + (parts.day ?? 0)
    }
}

struct CalorProvider: TimelineProvider {
    func placeholder(in context: Context) -> CalorEntry {
        .sample
    }

    func getSnapshot(in context: Context, completion: @escaping (CalorEntry) -> Void) {
        completion(context.isPreview ? .sample : .load(for: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalorEntry>) -> Void) {
        let now = Date.now
        let calendar = Calendar.current
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
            ?? now.addingTimeInterval(60 * 60)
        // The app refreshes the widget whenever something is logged; the second
        // entry starts the new day at zero.
        completion(Timeline(entries: [.load(for: now), .load(for: midnight)], policy: .after(midnight)))
    }
}

struct CalorWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: CalorEntry

    var body: some View {
        if !entry.hasData {
            VStack(spacing: 6) {
                Image(systemName: "fork.knife")
                    .font(.title2)
                Text("Open Calor to start")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        } else {
            switch family {
            case .systemMedium: medium
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            default: small
            }
        }
    }

    private var isOver: Bool { entry.remaining < 0 }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.quaternary, lineWidth: 9)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(isOver ? Color.orange : Color.accentColor,
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text(abs(entry.remaining), format: .number)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                Text(isOver ? "kcal over" : "kcal left")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
        }
    }

    private var small: some View {
        VStack(spacing: 8) {
            ring
            HStack {
                Text("\(entry.eaten.formatted()) of \(entry.goal.formatted())")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer(minLength: 0)
                if entry.streak > 0 {
                    Label("\(entry.streak)", systemImage: "flame.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            ring
                .frame(width: 112, height: 112)
            VStack(alignment: .leading, spacing: 7) {
                row("\(entry.eaten.formatted()) of \(entry.goal.formatted()) kcal", symbol: "fork.knife", color: .accentColor)
                if entry.proteinTarget > 0 {
                    row("\(entry.protein) of \(entry.proteinTarget) g protein", symbol: "bolt.heart.fill", color: .pink)
                }
                row("\(entry.water) of \(entry.waterGoal) glasses", symbol: "drop.fill", color: .blue)
                if entry.streak > 0 {
                    row("\(entry.streak)-day streak", symbol: "flame.fill", color: .orange)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func row(_ text: String, symbol: String, color: Color) -> some View {
        Label {
            Text(text)
                .font(.caption)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(color)
        }
    }

    private var circular: some View {
        Gauge(value: entry.progress) {
            Image(systemName: "fork.knife")
        } currentValueLabel: {
            Text(abs(entry.remaining), format: .number)
                .minimumScaleFactor(0.5)
        }
        .gaugeStyle(.accessoryCircularCapacity)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isOver ? "\(abs(entry.remaining)) kcal over" : "\(entry.remaining) kcal left")
                .font(.headline)
            Text("\(entry.eaten) of \(entry.goal) kcal eaten")
                .font(.caption)
            ProgressView(value: entry.progress)
        }
    }
}

struct CalorWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "CalorWidget", provider: CalorProvider()) { entry in
            CalorWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Calories left")
        .description("Today's calories left, with protein, water and your streak.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

@main
struct CalorWidgetBundle: WidgetBundle {
    var body: some Widget {
        CalorWidget()
    }
}

#Preview(as: .systemSmall) {
    CalorWidget()
} timeline: {
    CalorEntry.sample
}
