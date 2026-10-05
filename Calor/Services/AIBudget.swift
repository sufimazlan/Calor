//
//  AIBudget.swift
//  Calor
//

import Foundation

/// Keeps Claude spending on this phone within a monthly limit (PRD section 9).
///
/// Two layers protect the US$10 a month: the Claude Console's workspace spend
/// limit (US$10 for both phones) is the hard cap Anthropic enforces, and this
/// guard keeps each phone within its share (at most US$5) and stops runaway use.
/// Before each request it checks the most that request could cost; afterwards
/// it records what Claude reports it actually cost.
struct AIBudget {
    static let maxMonthlyLimit = 5.0
    static let minMonthlyLimit = 0.5
    static let dailyLimit = 25
    /// Generous token estimates for the check before a request (a 768 px photo is
    /// about 600 tokens, the instructions and answer format about 1,000).
    static let photoInputTokens = 3000
    static let textInputTokens = 1500

    var defaults = UserDefaults.standard
    var calendar = Calendar.current
    var now: () -> Date = { .now }

    // MARK: - Reading

    /// This phone's limit in US dollars, between `minMonthlyLimit` and `maxMonthlyLimit`.
    var monthlyLimit: Double {
        let saved = defaults.object(forKey: SettingsKey.aiMonthlyLimitUSD) as? Double ?? Self.maxMonthlyLimit
        return min(max(saved, Self.minMonthlyLimit), Self.maxMonthlyLimit)
    }

    var spentThisMonth: Double {
        guard defaults.string(forKey: SettingsKey.aiSpendMonth) == monthKey else { return 0 }
        return Double(defaults.integer(forKey: SettingsKey.aiSpendMicros)) / 1_000_000
    }

    var analysesThisMonth: Int {
        defaults.string(forKey: SettingsKey.aiSpendMonth) == monthKey ? defaults.integer(forKey: SettingsKey.aiCallsMonth) : 0
    }

    var analysesToday: Int {
        defaults.string(forKey: SettingsKey.aiCallsDay) == dayKey ? defaults.integer(forKey: SettingsKey.aiCallsToday) : 0
    }

    var fallbacksUnsupported: Bool {
        defaults.bool(forKey: SettingsKey.aiFallbacksUnsupported)
    }

    /// The most one request could cost: generous input plus the full answer
    /// allowance, twice over if a fallback model might run as well.
    static func worstCaseCost(for input: MealInput, model: ClaudeModel, fallbacks: Bool) -> Double {
        let inputTokens: Int
        switch input {
        case .photo: inputTokens = photoInputTokens
        case .text: inputTokens = textInputTokens
        }
        let once = model.cost(inputTokens: inputTokens, outputTokens: ClaudeRequest.maxTokens)
        return fallbacks ? once * 2 : once
    }

    // MARK: - Checking and recording

    /// Throws `ClaudeError.budget` if this request could go over a limit.
    func checkAllowed(worstCase: Double) throws {
        if analysesToday >= Self.dailyLimit {
            throw ClaudeError.budget("You've used today's \(Self.dailyLimit) analyses, the daily limit that guards against runaway costs. It resets at midnight. You can still add meals by hand.")
        }
        if spentThisMonth + worstCase > monthlyLimit {
            let raise = monthlyLimit < Self.maxMonthlyLimit ? " or raise the limit in Settings" : ""
            throw ClaudeError.budget("This month's Claude budget on this phone (\(Self.money(monthlyLimit))) is used up. It resets on the 1st. You can still add meals by hand\(raise).")
        }
    }

    /// Adds a request's cost. Rounded up to the next millionth of a dollar.
    func record(cost: Double) {
        let month = monthKey
        if defaults.string(forKey: SettingsKey.aiSpendMonth) != month {
            defaults.set(month, forKey: SettingsKey.aiSpendMonth)
            defaults.set(0, forKey: SettingsKey.aiSpendMicros)
            defaults.set(0, forKey: SettingsKey.aiCallsMonth)
        }
        let day = dayKey
        if defaults.string(forKey: SettingsKey.aiCallsDay) != day {
            defaults.set(day, forKey: SettingsKey.aiCallsDay)
            defaults.set(0, forKey: SettingsKey.aiCallsToday)
        }
        let micros = Int((max(cost, 0) * 1_000_000).rounded(.up))
        defaults.set(defaults.integer(forKey: SettingsKey.aiSpendMicros) + micros, forKey: SettingsKey.aiSpendMicros)
        defaults.set(defaults.integer(forKey: SettingsKey.aiCallsMonth) + 1, forKey: SettingsKey.aiCallsMonth)
        defaults.set(defaults.integer(forKey: SettingsKey.aiCallsToday) + 1, forKey: SettingsKey.aiCallsToday)
    }

    func markFallbacksUnsupported() {
        defaults.set(true, forKey: SettingsKey.aiFallbacksUnsupported)
    }

    // MARK: - Helpers

    static func money(_ dollars: Double) -> String {
        "US$" + String(format: dollars < 0.1 && dollars > 0 ? "%.3f" : "%.2f", dollars)
    }

    private var monthKey: String {
        let parts = calendar.dateComponents([.year, .month], from: now())
        return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
    }

    private var dayKey: String {
        let parts = calendar.dateComponents([.year, .month, .day], from: now())
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
