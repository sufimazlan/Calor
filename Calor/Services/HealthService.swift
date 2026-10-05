//
//  HealthService.swift
//  Calor
//

import Foundation
import HealthKit

/// The Apple Health settings, read where they're needed.
enum HealthSettings {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: SettingsKey.healthEnabled)
    }

    /// Percent of workout calories added to the day's goal (0, 50 or 100).
    static var workoutShare: Int {
        isEnabled ? UserDefaults.standard.integer(forKey: SettingsKey.healthWorkoutShare) : 0
    }

    static var writesWeight: Bool {
        isEnabled && (UserDefaults.standard.object(forKey: SettingsKey.healthWritesWeight) as? Bool ?? true)
    }

    static var readsWeight: Bool {
        isEnabled && (UserDefaults.standard.object(forKey: SettingsKey.healthReadsWeight) as? Bool ?? true)
    }
}

/// Apple Health: workout calories for the day's goal, and weight in both
/// directions. Only used after the user turns it on in Settings.
enum HealthService {
    private static let store = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    private static var bodyMass: HKQuantityType { HKQuantityType(.bodyMass) }
    private static var activeEnergy: HKQuantityType { HKQuantityType(.activeEnergyBurned) }

    /// Shows iOS's Health permission sheet the first time. Throws if this build of
    /// the app doesn't have the HealthKit capability.
    static func requestAccess() async throws {
        try await store.requestAuthorization(toShare: [bodyMass],
                                             read: [bodyMass, activeEnergy, HKObjectType.workoutType()])
    }

    /// Calories burned in workouts that started on this day (Apple Watch, Fitness, Strava…).
    static func workoutCalories(on day: Date, calendar: Calendar = .current) async throws -> Int {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        let query = HKSampleQueryDescriptor(predicates: [.workout(predicate)], sortDescriptors: [])
        let workouts = try await query.result(for: store)
        let kcal = workouts.reduce(0.0) { total, workout in
            total + (workout.statistics(for: activeEnergy)?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0)
        }
        return Int(kcal.rounded())
    }

    static func saveWeight(kg: Double, date: Date) async throws {
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        try await store.save(HKQuantitySample(type: bodyMass, quantity: quantity, start: date, end: date))
    }

    /// Weights other apps and devices (e.g. a smart scale) saved since a date, oldest
    /// first. Weights Calor saved itself are left out.
    static func weights(since date: Date) async throws -> [WeighIn] {
        let predicate = HKQuery.predicateForSamples(withStart: date, end: nil, options: .strictStartDate)
        let query = HKSampleQueryDescriptor(predicates: [.quantitySample(type: bodyMass, predicate: predicate)],
                                            sortDescriptors: [SortDescriptor(\.startDate)])
        let samples = try await query.result(for: store)
        let ownBundle = Bundle.main.bundleIdentifier
        return samples
            .filter { $0.sourceRevision.source.bundleIdentifier != ownBundle }
            .map { WeighIn(date: $0.startDate, kg: $0.quantity.doubleValue(for: .gramUnit(with: .kilo))) }
    }
}
