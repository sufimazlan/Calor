//
//  EntryFormView.swift
//  Calor
//

import SwiftUI
import SwiftData

/// Add a food entry by hand, or edit an existing one.
struct EntryFormView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// The entry being edited, or nil when adding a new one.
    private let entry: FoodEntry?
    /// Called after saving, e.g. to close the screen that opened this one too.
    private let onSaved: () -> Void

    // Numbers are edited as text and parsed on save, so the Save button
    // updates as the user types.
    @State private var name: String
    @State private var caloriesText: String
    @State private var portion: String
    @State private var mealType: MealType
    @State private var timestamp: Date
    @State private var proteinText: String
    @State private var carbsText: String
    @State private var fatText: String
    @State private var notes: String

    init(entry: FoodEntry? = nil, onSaved: @escaping () -> Void = {}) {
        self.entry = entry
        self.onSaved = onSaved
        let now = Date.now
        _name = State(initialValue: entry?.name ?? "")
        _caloriesText = State(initialValue: entry.map { String($0.calories) } ?? "")
        _portion = State(initialValue: entry?.portion ?? "")
        _mealType = State(initialValue: entry?.mealType ?? .suggested(for: now))
        _timestamp = State(initialValue: entry?.timestamp ?? now)
        _proteinText = State(initialValue: Self.text(for: entry?.proteinG))
        _carbsText = State(initialValue: Self.text(for: entry?.carbsG))
        _fatText = State(initialValue: Self.text(for: entry?.fatG))
        _notes = State(initialValue: entry?.notes ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var calories: Int? {
        Int(caloriesText.trimmingCharacters(in: .whitespaces))
    }

    private var isValid: Bool {
        !trimmedName.isEmpty && (calories ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Food name", text: $name)
                    LabeledContent("Calories") {
                        TextField("kcal", text: $caloriesText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                    }
                    TextField("Portion, e.g. 1 plate (optional)", text: $portion)
                } footer: {
                    if !caloriesText.isEmpty && (calories ?? 0) <= 0 {
                        Text("Calories must be a positive whole number.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Text(meal.title).tag(meal)
                        }
                    }
                    DatePicker("Time", selection: $timestamp)
                }

                Section("Macros (optional)") {
                    macroField("Protein", text: $proteinText)
                    macroField("Carbs", text: $carbsText)
                    macroField("Fat", text: $fatText)
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle(entry == nil ? "Add Food" : "Edit Food")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
        }
    }

    private func macroField(_ title: String, text: Binding<String>) -> some View {
        LabeledContent(title) {
            TextField("g", text: text)
                .multilineTextAlignment(.trailing)
                .keyboardType(.decimalPad)
        }
    }

    private func save() {
        guard let calories, calories > 0, !trimmedName.isEmpty else { return }

        let target: FoodEntry
        if let entry {
            target = entry
        } else {
            target = FoodEntry(mealType: mealType, name: trimmedName, calories: calories)
            modelContext.insert(target)
        }

        target.name = trimmedName
        target.calories = calories
        target.portion = Self.nilIfBlank(portion)
        target.mealType = mealType
        target.timestamp = timestamp
        target.proteinG = Self.grams(from: proteinText)
        target.carbsG = Self.grams(from: carbsText)
        target.fatG = Self.grams(from: fatText)
        target.notes = Self.nilIfBlank(notes)

        onSaved()
        dismiss()
    }

    private static func nilIfBlank(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Accepts "12", "12.5" or "12,5". Blank or invalid input means "not set".
    private static func grams(from text: String) -> Double? {
        let normalized = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else { return nil }
        return value
    }

    private static func text(for grams: Double?) -> String {
        guard let grams else { return "" }
        return grams.formatted(.number.precision(.fractionLength(0...1)).grouping(.never))
    }
}

#Preview("Add") {
    EntryFormView()
        .modelContainer(for: [FoodEntry.self, WeightEntry.self, WaterLog.self], inMemory: true)
}
