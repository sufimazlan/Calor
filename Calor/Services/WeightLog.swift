//
//  WeightLog.swift
//  Calor
//

import Foundation
import SwiftData

/// Adds and removes weigh-ins, keeping the profile's current weight equal to the
/// newest one so the calorie maths stays right.
enum WeightLog {
    static func add(kg: Double, date: Date = .now, source: WeightSource, context: ModelContext) {
        context.insert(WeightEntry(date: date, kg: kg, source: source))
        try? context.save()
        syncProfileWeight(context: context)
        if source == .manual && HealthSettings.writesWeight {
            Task { try? await HealthService.saveWeight(kg: kg, date: date) }
        }
    }

    static func delete(_ entry: WeightEntry, context: ModelContext) {
        context.delete(entry)
        try? context.save()
        syncProfileWeight(context: context)
    }

    static func latest(context: ModelContext) -> WeightEntry? {
        var descriptor = FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        descriptor.fetchLimit = 1
        return (try? context.fetch(descriptor))?.first
    }

    /// Makes the newest weigh-in the profile's weight. The target weight is left
    /// alone, even if the new weight passes it.
    static func syncProfileWeight(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard let latest = latest(context: context),
              var profile = Profile(data: defaults.data(forKey: SettingsKey.profile)),
              abs(profile.weightKg - latest.kg) > 0.001 else { return }
        profile.weightKg = latest.kg
        defaults.set(profile.data, forKey: SettingsKey.profile)
    }

    /// After setup or a profile edit: records the weight entered there as a weigh-in,
    /// unless it's the same as the newest one.
    static func recordProfileWeight(_ kg: Double, context: ModelContext) {
        if let latest = latest(context: context), abs(latest.kg - kg) < 0.05 { return }
        add(kg: kg, source: .profile, context: context)
    }

    /// For profiles saved before weigh-ins existed (v0.6 and earlier): records the
    /// profile weight as the first weigh-in and starts the plan today.
    static func preparePlan(context: ModelContext) {
        let defaults = UserDefaults.standard
        guard var profile = Profile(data: defaults.data(forKey: SettingsKey.profile)) else { return }
        if latest(context: context) == nil {
            context.insert(WeightEntry(kg: profile.weightKg, source: .profile))
            try? context.save()
        }
        guard profile.planStartDate == nil else { return }
        profile.startPlan()
        defaults.set(profile.data, forKey: SettingsKey.profile)
    }

    /// Adds weights other apps saved in Apple Health since the last import
    /// (the last 30 days the first time).
    static func importFromHealth(context: ModelContext) async {
        guard HealthSettings.readsWeight else { return }
        let defaults = UserDefaults.standard
        let last = defaults.double(forKey: SettingsKey.healthLastWeightImport)
        let since = last > 0
            ? Date(timeIntervalSince1970: last + 1)
            : Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
        guard let weights = try? await HealthService.weights(since: since), !weights.isEmpty else { return }

        let existing = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        for weight in weights {
            let isKnown = existing.contains {
                abs($0.date.timeIntervalSince(weight.date)) < 60 && abs($0.kg - weight.kg) < 0.05
            }
            if !isKnown {
                context.insert(WeightEntry(date: weight.date, kg: weight.kg, source: .health))
            }
        }
        try? context.save()
        if let newest = weights.map(\.date).max() {
            defaults.set(newest.timeIntervalSince1970, forKey: SettingsKey.healthLastWeightImport)
        }
        syncProfileWeight(context: context)
    }
}
