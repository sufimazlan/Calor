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

/// A meal described in words, waiting to be analysed.
struct MealDescription: Identifiable {
    let id = UUID()
    let text: String
}

/// Analyses a meal photo or description, then shows the review screen (PRD 6.3):
/// edit or remove items, add missing ones, and save them as entries.
struct AnalysisView: View {
    private enum Subject {
        case photo(UIImage)
        case text(String)
    }

    private enum Phase: Equatable {
        /// Photo on screen with an optional note, waiting for Analyse.
        case ready
        case analyzing
        case review
        case notFood
        case failed(String, canRetry: Bool)
    }

    private static let hintChips = ["Half rice", "Extra rice", "No sugar", "Less sweet", "Less oil",
                                    "Shared plate", "Small portion", "Large portion", "Homemade"]

    private let subject: Subject
    private let analyzer: any FoodAnalyzer
    private let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase
    @State private var hint = ""
    @State private var items: [DraftItem] = []
    @State private var confidence = Confidence.medium
    @State private var notes: String?
    @State private var mealType = MealType.suggested()
    @State private var resultSource: String?
    @State private var isAddingManually = false

    init(photo: MealPhoto, analyzer: any FoodAnalyzer = FoodAnalyzers.current, onSaved: @escaping () -> Void = {}) {
        subject = .photo(photo.image)
        self.analyzer = analyzer
        self.onSaved = onSaved
        let asksForNote = UserDefaults.standard.object(forKey: SettingsKey.analysisAsksForNote) as? Bool ?? true
        _phase = State(initialValue: asksForNote ? .ready : .analyzing)
    }

    init(description: MealDescription, analyzer: any FoodAnalyzer = FoodAnalyzers.current,
         onSaved: @escaping () -> Void = {}) {
        subject = .text(description.text)
        self.analyzer = analyzer
        self.onSaved = onSaved
        _phase = State(initialValue: .analyzing)
    }

    private var isReviewing: Bool {
        phase == .review
    }

    private var totalCalories: Int {
        items.compactMap(\.calories).reduce(0, +)
    }

    private var mealScore: Int? {
        HealthScore.meal(items.map { (calories: $0.calories ?? 0, score: $0.healthScore) })
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
        .task {
            if phase == .analyzing {
                await analyze()
            }
        }
        .sheet(isPresented: $isAddingManually) {
            EntryFormView(onSaved: finish)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .ready:
            readyView
        case .analyzing:
            VStack(spacing: 24) {
                subjectPreview
                ProgressView("Analysing your meal…")
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
        case .review:
            reviewList
        case .notFood:
            problemView(
                title: "That doesn't look like food",
                message: notes ?? "Try another photo, or add the meal manually.",
                systemImage: "questionmark.circle",
                canRetry: false
            )
        case .failed(let message, let canRetry):
            problemView(
                title: "Couldn't analyse your meal",
                message: message,
                systemImage: "exclamationmark.triangle",
                canRetry: canRetry
            )
        }
    }

    @ViewBuilder
    private var subjectPreview: some View {
        switch subject {
        case .photo(let image):
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 12))
                .frame(maxHeight: 300)
        case .text(let text):
            Text(text)
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: 12))
        }
    }

    // MARK: - Before analysing

    private var readyView: some View {
        ScrollView {
            VStack(spacing: 20) {
                subjectPreview

                VStack(alignment: .leading, spacing: 10) {
                    Text("Anything Claude should know?")
                        .font(.headline)
                    TextField("Optional, e.g. half rice, no sugar", text: $hint, axis: .vertical)
                        .lineLimit(1...3)
                        .textFieldStyle(.roundedBorder)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.hintChips, id: \.self) { chip in
                                Button(chip) {
                                    addHint(chip)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                            }
                        }
                    }
                }

                Button {
                    Task { await analyze() }
                } label: {
                    Label("Analyse", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Text(modeCaption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var modeCaption: String {
        if analyzer.isDemo {
            return "Demo mode: sample results until a Claude API key is added in Settings."
        }
        let budget = AIBudget()
        return "Claude \(ClaudeModel.current.title) · \(AIBudget.money(budget.spentThisMonth)) of \(AIBudget.money(budget.monthlyLimit)) used this month"
    }

    private func addHint(_ chip: String) {
        let current = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !current.localizedCaseInsensitiveContains(chip) else { return }
        hint = current.isEmpty ? chip.lowercased() : "\(current), \(chip.lowercased())"
    }

    // MARK: - Review

    private var reviewList: some View {
        List {
            Section {
                switch subject {
                case .photo(let image):
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .listRowInsets(EdgeInsets())
                case .text(let text):
                    Text(text)
                }
            } footer: {
                if let note = ClaudeRequest.cleaned(hint, limit: ClaudeRequest.hintLimit) {
                    Text("Your note: \(note)")
                }
            }

            if analyzer.isDemo {
                Section {
                    Label("Demo result: sample data, not from your meal. Real analysis starts once a Claude API key is added in Settings.",
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
                if let mealScore {
                    LabeledContent("Health score") {
                        HStack(spacing: 6) {
                            Text("\(mealScore)/10 · \(HealthScore.label(mealScore))")
                                .foregroundStyle(.secondary)
                            HealthScoreBadge(score: mealScore)
                        }
                    }
                }
            } footer: {
                if let resultSource {
                    Text(resultSource)
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
                Button("Try again") {
                    Task { await analyze() }
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Add manually") {
                isAddingManually = true
            }
        }
    }

    // MARK: - Actions

    private func analyze() async {
        phase = .analyzing
        let input: MealInput
        switch subject {
        case .photo(let image):
            guard let jpeg = ImageProcessing.analysisJPEG(from: image) else {
                phase = .failed("This photo couldn't be read. Try another one.", canRetry: false)
                return
            }
            input = .photo(jpeg: jpeg, hint: hint)
        case .text(let text):
            input = .text(text)
        }

        do {
            let result = try await analyzer.analyze(input)
            let analysis = result.analysis
            notes = analysis.notes
            guard analysis.isFood, !analysis.items.isEmpty else {
                phase = .notFood
                return
            }
            items = analysis.items.map { DraftItem($0) }
            confidence = analysis.confidence
            if let model = result.modelName {
                let cost = result.costUSD.map { " · cost about \(AIBudget.money($0))" } ?? ""
                resultSource = "Estimated by Claude \(model)\(cost)."
            }
            phase = .review
        } catch is CancellationError {
            // The sheet was closed while waiting; nothing to show.
        } catch let error as ClaudeError {
            phase = .failed(error.localizedDescription, canRetry: error.canRetry)
        } catch {
            phase = .failed("Something went wrong. Check your internet connection and try again.", canRetry: true)
        }
    }

    private func save() {
        var thumbnail: Data?
        var source = EntrySource.text
        if case .photo(let image) = subject {
            thumbnail = ImageProcessing.thumbnailJPEG(from: image)
            source = .photo
        }
        let note = ClaudeRequest.cleaned(hint, limit: ClaudeRequest.hintLimit)
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
                source: source,
                confidence: confidence,
                thumbnail: thumbnail,
                notes: note,
                healthScore: item.healthScore
            ))
        }
        finish()
    }

    private func finish() {
        onSaved()
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
    var healthScore: Int?

    init(_ item: FoodAnalysis.Item) {
        name = item.name
        portion = item.portion ?? ""
        caloriesText = String(item.calories)
        proteinG = item.proteinG
        carbsG = item.carbsG
        fatG = item.fatG
        healthScore = item.healthScore
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
            HStack(alignment: .firstTextBaseline) {
                TextField("Food name", text: $item.name, axis: .vertical)
                    .font(.headline)
                if let score = item.healthScore {
                    HealthScoreBadge(score: score)
                }
            }
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
