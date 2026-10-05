//
//  Advice.swift
//  Calor
//

import Foundation

/// "What's next" tips for the Today screen. Worked out on the phone from
/// today's numbers, so they're free and work offline (no API call).
enum Advice {
    static func whatsNext(
        eaten: Int,
        goal: Int,
        proteinG: Double,
        carbsG: Double,
        fatG: Double,
        proteinTargetG: Int,
        diet: DietType = .balanced,
        hasEntries: Bool,
        now: Date = .now
    ) -> String {
        let hour = Calendar.current.component(.hour, from: now)
        let remaining = goal - eaten

        guard hasEntries else {
            return hour < 11
                ? "Start the day by snapping your breakfast."
                : "Nothing logged yet today. Snap your next meal to start tracking."
        }

        var tip: String
        if remaining < 0 {
            tip = "You're \((-remaining).formatted()) kcal over today's goal. Keep the rest of today light: water, plain tea, or fruit if you're hungry."
        } else if remaining <= 150 {
            tip = "Almost at your goal, with \(remaining) kcal left. A sugar-free drink or a piece of fruit still fits."
        } else {
            switch hour {
            case ..<11:
                tip = "\(remaining.formatted()) kcal left today. That's about \((remaining / 2).formatted()) kcal each for lunch and dinner."
            case ..<16:
                tip = "\(remaining.formatted()) kcal left for the rest of today. Plan dinner around \(min(remaining, 700).formatted()) kcal."
            case ..<21:
                tip = "\(remaining.formatted()) kcal left for dinner and anything after."
            default:
                tip = "\(remaining.formatted()) kcal left. If you snack tonight, keep it under \(min(remaining, 300)) kcal."
            }
        }

        // Protein check, only when macros were logged.
        let macroCalories = proteinG * 4 + carbsG * 4 + fatG * 9
        guard macroCalories > 0 else { return tip }
        let proteinIdea = "\(diet.proteinIdeas) would help at your next meal."
        if proteinTargetG > 0 {
            // Expect about half the target by mid-afternoon and three quarters by evening.
            let expectedShare = hour >= 19 ? 0.75 : (hour >= 15 ? 0.5 : 0)
            if proteinG < Double(proteinTargetG) * expectedShare {
                tip += " Protein so far: \(Int(proteinG.rounded())) of \(proteinTargetG) g. \(proteinIdea)"
            }
        } else if eaten >= 800, proteinG * 4 / macroCalories < 0.15 {
            tip += " Protein is low so far. \(proteinIdea)"
        }
        return tip
    }

    /// A second tip based on the setup answers: what gets in the way (obstacle)
    /// and what the user wants (aspiration). Changes daily, stays the same all day.
    static func personalTip(
        obstacle: Obstacle?,
        aspiration: Aspiration?,
        diet: DietType = .balanced,
        remaining: Int,
        streak: Int,
        healthScoreToday: Int?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String? {
        let day = calendar.ordinality(of: .day, in: .era, for: now) ?? 0
        let tips = [
            obstacle.map { obstacleTip($0, diet: diet, remaining: remaining, streak: streak, day: day) },
            aspiration.map { aspirationTip($0, streak: streak, healthScoreToday: healthScoreToday) },
        ].compactMap { $0 }
        guard !tips.isEmpty else { return nil }
        return tips[day % tips.count]
    }

    private static func obstacleTip(_ obstacle: Obstacle, diet: DietType, remaining: Int, streak: Int, day: Int) -> String {
        switch obstacle {
        case .consistency:
            return streak >= 2
                ? "You're on a \(streak)-day streak. Log every meal today to keep it going."
                : "Consistency beats perfection: log every meal today, even small snacks."
        case .unhealthyHabits:
            let swaps = [
                "Swap teh tarik for teh-o kosong to save about 100 kcal a cup.",
                "Ask for kurang manis (less sweet) drinks to save about 40 kcal each.",
                "Choose grilled or steamed instead of fried to save about 150 kcal.",
                "Ask for less kuah (gravy) on your rice to save about 100 kcal.",
                "Half rice (nasi separuh) saves about 120 kcal.",
            ]
            return swaps[day % swaps.count]
        case .support:
            return "Share today's progress with someone close. People with support stick with their goals longer."
        case .busySchedule:
            return "Busy day? Snap first and fix details later. For repeat meals, use Add another way → From yesterday."
        case .inspiration:
            let ideas = MealIdea.ideas(fitting: remaining, diet: diet, day: day)
            guard !ideas.isEmpty else {
                return "Short on ideas? Fruit, plain yoghurt or a cup of unsweetened soy milk all fit a light evening."
            }
            let list = ideas.map { "\($0.name.lowercased()) (about \($0.kcal) kcal)" }.joined(separator: ", ")
            return "Ideas that fit your \(remaining.formatted()) kcal: \(list)."
        }
    }

    private static func aspirationTip(_ aspiration: Aspiration, streak: Int, healthScoreToday: Int?) -> String {
        switch aspiration {
        case .healthier:
            guard let score = healthScoreToday else {
                return "Fill half your plate with vegetables at your next meal."
            }
            return score >= 7
                ? "Today's meals score \(score)/10 for health. Nice work."
                : "Today's meals score \(score)/10 for health. Vegetables or fruit at your next meal will lift it."
        case .energy:
            return "For steady energy, pair carbs with protein and drink water through the day."
        case .motivated:
            return streak >= 3
                ? "\(streak) days of logging in a row. Small steps add up."
                : "Every meal you log makes your trends more accurate. Small steps add up."
        case .body:
            return "Progress isn't only the scale: notice how your clothes fit and how you feel."
        }
    }
}

/// Malaysian meals and snacks with typical calories, for meal ideas.
struct MealIdea {
    enum Tag {
        case meat, fish, egg, dairy, highCarb
    }

    let name: String
    let kcal: Int
    let tags: Set<Tag>

    static let all: [MealIdea] = [
        MealIdea(name: "Chicken rice with steamed chicken, less rice", kcal: 450, tags: [.meat, .highCarb]),
        MealIdea(name: "Yong tau foo soup", kcal: 350, tags: [.fish]),
        MealIdea(name: "Grilled fish with ulam and half rice", kcal: 450, tags: [.fish, .highCarb]),
        MealIdea(name: "Thosai with dhal", kcal: 250, tags: [.highCarb]),
        MealIdea(name: "Chapati with dhal", kcal: 350, tags: [.highCarb]),
        MealIdea(name: "Vegetable soup with tofu and half rice", kcal: 400, tags: [.highCarb]),
        MealIdea(name: "Ayam percik with half rice", kcal: 550, tags: [.meat, .highCarb]),
        MealIdea(name: "Fish head bee hoon soup", kcal: 400, tags: [.fish, .highCarb]),
        MealIdea(name: "Tofu and kangkung stir-fry", kcal: 250, tags: []),
        MealIdea(name: "Grilled chicken with salad", kcal: 400, tags: [.meat]),
        MealIdea(name: "Steamed fish with vegetables", kcal: 350, tags: [.fish]),
        MealIdea(name: "Tempeh goreng, 3 pieces", kcal: 250, tags: []),
        MealIdea(name: "Popiah basah, 2 rolls", kcal: 220, tags: [.egg, .highCarb]),
        MealIdea(name: "Oats with low-fat milk", kcal: 250, tags: [.dairy, .highCarb]),
        MealIdea(name: "Greek yoghurt with fruit", kcal: 180, tags: [.dairy]),
        MealIdea(name: "Boiled eggs, 2", kcal: 150, tags: [.egg]),
        MealIdea(name: "Roasted peanuts, a small handful", kcal: 170, tags: []),
        MealIdea(name: "Sweet corn in a cup", kcal: 150, tags: [.highCarb]),
        MealIdea(name: "Unsweetened soy milk", kcal: 100, tags: []),
        MealIdea(name: "Papaya or watermelon, 1 cup", kcal: 60, tags: [.highCarb]),
    ]

    /// Up to three ideas within `kcal` that suit the diet. Main meals when there's
    /// room for one, snacks otherwise. Rotates daily.
    static func ideas(fitting kcal: Int, diet: DietType, day: Int) -> [MealIdea] {
        let fitting = all.filter { $0.kcal <= kcal && diet.allows($0.tags) }
        let mains = fitting.filter { $0.kcal >= 200 }
        let pool = kcal >= 350 && !mains.isEmpty ? mains : fitting
        guard !pool.isEmpty else { return [] }
        let start = ((day % pool.count) + pool.count) % pool.count
        return (0..<min(3, pool.count)).map { pool[(start + $0) % pool.count] }
    }
}

private extension DietType {
    func allows(_ tags: Set<MealIdea.Tag>) -> Bool {
        let excluded: Set<MealIdea.Tag> = switch self {
        case .vegan: [.meat, .fish, .egg, .dairy]
        case .vegetarian: [.meat, .fish]
        case .pescatarian: [.meat]
        case .keto, .lowCarb: [.highCarb]
        case .paleo: [.dairy, .highCarb]
        default: []
        }
        return tags.isDisjoint(with: excluded)
    }
}
