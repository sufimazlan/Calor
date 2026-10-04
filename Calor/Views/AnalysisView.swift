//
//  AnalysisView.swift
//  Calor
//

import SwiftUI
import SwiftData
import UIKit

/// A photo the user took or picked, waiting to be analysed.
struct MealPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Sends the photo for analysis, then shows the review screen (PRD 6.3):
/// edit or remove items, add missing ones, and save them as entries.
struct AnalysisView: View {
    let photo: MealPhoto
    var analyzer: any FoodAnalyzer = DemoFoodAnalyzer()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private enum Phase {
        case analyzing, review, notFood
        case failed(String)
    }

    @State private var phase = Phase.analyzing
    @State private var items: [DraftItem] = []
    @State private var confidence = Confidence.medium
    @State private var notes: String?
    @State private var mealType = MealType.suggested()
    @State private var isAddingManually = false

    private var isReviewing: Bool {
        if case .review = phase { return true }
        return false
    }

    private var totalCalories: Int {
        items.compactMap(\.calories).reduce(0, +)
    }

    private var canSave: Bool {
        !items.isEmpty && items.allSatisfy(\.isValid)
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Your Meal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    if isReviewing {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") { save() }
                                .disabled(!canSave)
                        }
                    }
                }
        }
        .task { await analyze() }
        .sheet(isPresented: $isAddingManually) {
            EntryFormView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .analyzing:
            VStack(spacing: 24) {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 12))
                    .frame(maxHeight: 320)
                ProgressView("Analysing your meal…")
            }
            .padding()
        case .review:
            reviewList
        case .notFood:
            problemView(
                title: "That doesn't look like food",
                message: "Try another photo, or add the meal manually.",
                systemImage: "questionmark.circle",
                canRetry: false
            )
        case .failed(let message):
            problemView(
                title: "Couldn't analyse the photo",
                message: message,
                systemImage: "exclamationmark.triangle",
                canRetry: true
            )
        }
    }

    private var reviewList: some View {
        List {
            Section {
                Image(uiImage: photo.image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .listRowInsets(EdgeInsets())
            }

            if analyzer.isDemo {
                Section {
                    Label("Demo result: sample data, not from your photo. Real analysis starts once a Claude API key is added.",
                          systemImage: "info.circle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            if confidence == .low {
                Section {
                    Label {
                        Text("Please check these estimates. Some items were hard to judge.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                ForEach($items) { $item in
                    DraftItemRow(item: $item)
                }
                .onDelete { items.remove(atOffsets: $0) }

                Button("Add item", systemImage: "plus") {
                    items.append(DraftItem())
                }
            } header: {
                Text("Detected items")
            } footer: {
                Text("Edit anything that looks off. Swipe left to remove an item.")
            }

            Section {
                Picker("Meal", selection: $mealType) {
                    ForEach(MealType.allCases) { meal in
                        Text(meal.title).tag(meal)
                    }
                }
                LabeledContent("Total") {
                    Text("\(totalCalories.formatted()) kcal")
                        .font(.headline)
                        .monospacedDigit()
                }
            }

            if let notes {
                Section("Note") {
                    Text(notes)
                }
            }
        }
    }

    private func problemView(title: String, message: String, systemImage: String, canRetry: Bool) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if canRetry {
                Button("Retry") {
                    Task { await analyze() }
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Add manually") {
                isAddingManually = true
            }
        }
    }

    private func analyze() async {
        phase = .analyzing
        guard let jpeg = ImageProcessing.analysisJPEG(from: photo.image) else {
            phase = .failed("This photo couldn't be read. Try another one.")
            return
        }
        do {
            let result = try await analyzer.analyze(jpeg: jpeg, hint: nil)
            guard result.isFood, !result.items.isEmpty else {
                phase = .notFood
                return
            }
            items = result.items.map { DraftItem($0) }
            confidence = result.confidence
            notes = result.notes
            phase = .review
        } catch is CancellationError {
            // The sheet was closed while waiting; nothing to show.
        } catch {
            phase = .failed("Check your internet connection and try again. Your photo is kept.")
        }
    }

    private func save() {
        let thumbnail = ImageProcessing.thumbnailJPEG(from: photo.image)
        let now = Date.now
        for item in items {
            guard let calories = item.calories else { continue }
            let portion = item.portion.trimmingCharacters(in: .whitespacesAndNewlines)
            modelContext.insert(FoodEntry(
                timestamp: now,
                mealType: mealType,
                name: item.name.trimmingCharacters(in: .whitespacesAndNewlines),
                portion: portion.isEmpty ? nil : portion,
                calories: calories,
                proteinG: item.proteinG,
                carbsG: item.carbsG,
                fatG: item.fatG,
                source: .photo,
                confidence: confidence,
                thumbnail: thumbnail
            ))
        }
        dismiss()
    }
}

/// One detected item while it's being reviewed. Calories are edited as text.
private struct DraftItem: Identifiable {
    let id = UUID()
    var name: String
    var portion: String
    var caloriesText: String
    var proteinG: Double?
    var carbsG: Double?
    var fatG: Double?

    init(_ item: FoodAnalysis.Item) {
        name = item.name
        portion = item.portion ?? ""
        caloriesText = String(item.calories)
        proteinG = item.proteinG
        carbsG = item.carbsG
        fatG = item.fatG
    }

    init() {
        name = ""
        portion = ""
        caloriesText = ""
    }

    var calories: Int? {
        Int(caloriesText.trimmingCharacters(in: .whitespaces))
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && (calories ?? 0) > 0
    }

    var macroSummary: String? {
        let parts = [("Protein", proteinG), ("Carbs", carbsG), ("Fat", fatG)].compactMap { label, grams in
            grams.map { "\(label) \(Int($0.rounded())) g" }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct DraftItemRow: View {
    @Binding var item: DraftItem

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Food name", text: $item.name, axis: .vertical)
                .font(.headline)
            HStack {
                TextField("Portion", text: $item.portion)
                    .foregroundStyle(.secondary)
                TextField("0", text: $item.caloriesText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .frame(width: 70)
                Text("kcal")
                    .foregroundStyle(.secondary)
            }
            if let macros = item.macroSummary {
                Text(macros)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
