//
//  FoodAnalyzer.swift
//  Calor
//

import Foundation

/// Turns a meal photo into a calorie estimate.
protocol FoodAnalyzer {
    /// True when results are sample data rather than a real analysis.
    var isDemo: Bool { get }

    /// - Parameters:
    ///   - jpeg: the photo, already resized to 768 px (PRD 6.3).
    ///   - hint: optional note from the user, e.g. "half portion of rice".
    func analyze(jpeg: Data, hint: String?) async throws -> FoodAnalysis
}

/// Returns realistic sample results without calling any API, so the whole
/// photo flow can be built and tried before a Claude API key is set up.
/// It does not look at the photo.
struct DemoFoodAnalyzer: FoodAnalyzer {
    var isDemo: Bool { true }

    func analyze(jpeg: Data, hint: String?) async throws -> FoodAnalysis {
        try await Task.sleep(for: .seconds(1.5))
        return Self.samples.randomElement() ?? Self.samples[0]
    }

    private static let samples: [FoodAnalysis] = [
        FoodAnalysis(
            isFood: true,
            items: [
                .init(name: "Nasi lemak (rice, sambal, egg, peanuts, anchovies)", portion: "1 plate",
                      calories: 550, proteinG: 15, carbsG: 70, fatG: 22),
                .init(name: "Fried chicken (drumstick)", portion: "1 piece",
                      calories: 250, proteinG: 20, carbsG: 8, fatG: 15),
            ],
            confidence: .medium,
            notes: nil
        ),
        FoodAnalysis(
            isFood: true,
            items: [
                .init(name: "Roti canai", portion: "2 pieces", calories: 600, proteinG: 12, carbsG: 76, fatG: 26),
                .init(name: "Dhal curry", portion: "1 small bowl", calories: 120, proteinG: 6, carbsG: 16, fatG: 4),
                .init(name: "Teh tarik", portion: "1 cup", calories: 150, proteinG: 4, carbsG: 24, fatG: 4),
            ],
            confidence: .high,
            notes: nil
        ),
        FoodAnalysis(
            isFood: true,
            items: [
                .init(name: "Nasi campur (white rice)", portion: "1 cup", calories: 240, proteinG: 4, carbsG: 53, fatG: 0),
                .init(name: "Ayam masak merah", portion: "1 piece", calories: 280, proteinG: 22, carbsG: 10, fatG: 17),
                .init(name: "Stir-fried kangkung", portion: "1/2 cup", calories: 80, proteinG: 3, carbsG: 6, fatG: 5),
            ],
            confidence: .low,
            notes: "Sauce amount is hard to judge from the photo."
        ),
    ]
}
