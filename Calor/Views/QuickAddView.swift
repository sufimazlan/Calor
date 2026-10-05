//
//  QuickAddView.swift
//  Calor
//

import SwiftUI
import SwiftData
import UIKit

/// The other ways to add a meal when a photo isn't handy: describe it in words,
/// copy yesterday's meal, or pick a favourite or recent food with one tap.
/// Typing everything in by hand is the last option.
struct QuickAddView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query private var recentEntries: [FoodEntry]
    @Query private var favoriteEntries: [FoodEntry]
    @Query private var yesterdayEntries: [FoodEntry]

    @State private var mealDescription = ""
    @State private var describing: MealDescription?
    @State private var isAddingManually = false
    /// Rows tapped on this visit, to show a tick.
    @State private var added: Set<String> = []
    @State private var addCount = 0

    private let isDemo = KeychainStore.apiKey == nil

    init() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        _recentEntries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= monthAgo },
                               sort: \FoodEntry.timestamp, order: .reverse)
        _favoriteEntries = Query(filter: #Predicate<FoodEntry> { $0.isFavorite == true },
                                 sort: \FoodEntry.timestamp, order: .reverse)
        _yesterdayEntries = Query(filter: #Predicate<FoodEntry> { $0.timestamp >= yesterday && $0.timestamp < today },
                                  sort: \FoodEntry.timestamp)
    }

    private var trimmedDescription: String {
        mealDescription.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// One row per food, newest first.
    private var favorites: [FoodEntry] {
        unique(favoriteEntries)
    }

    /// Foods from the last 30 days that aren't already favourites.
    private var recents: [FoodEntry] {
        let favoriteKeys = Set(favorites.map(\.matchKey))
        return Array(unique(recentEntries).filter { !favoriteKeys.contains($0.matchKey) }.prefix(20))
    }

    private struct MealGroup: Identifiable {
        let meal: MealType
        let entries: [FoodEntry]
        var id: MealType { meal }
    }

    private var yesterdayMeals: [MealGroup] {
        MealType.allCases.compactMap { meal in
            let entries = yesterdayEntries.filter { $0.mealType == meal }
            return entries.isEmpty ? nil : MealGroup(meal: meal, entries: entries)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("e.g. 2 roti canai with dhal and a teh tarik", text: $mealDescription, axis: .vertical)
                        .lineLimit(2...4)
                    Button("Estimate calories", systemImage: "sparkles") {
                        describing = MealDescription(text: trimmedDescription)
                    }
                    .disabled(trimmedDescription.isEmpty)
                } header: {
                    Text("Describe it in words")
                } footer: {
                    Text(isDemo
                         ? "Demo mode: sample results until a Claude API key is added in Settings."
                         : "Claude estimates the calories from your words. Cheaper than a photo.")
                }

                if !yesterdayMeals.isEmpty {
                    Section {
                        ForEach(yesterdayMeals) { group in
                            let key = "yesterday-\(group.meal.rawValue)"
                            QuickAddRow(
                                title: group.meal.title,
                                detail: "\(group.entries.map(\.name).joined(separator: ", ")) · \(group.entries.reduce(0) { $0 + $1.calories }.formatted()) kcal",
                                thumbnail: group.entries.first(where: { $0.thumbnail != nil })?.thumbnail,
                                isAdded: added.contains(key)
                            ) {
                                EntryActions.copyToToday(group.entries, context: modelContext)
                                markAdded(key)
                            }
                        }
                    } header: {
                        Text("Same as yesterday")
                    } footer: {
                        Text("Copies the whole meal to today.")
                    }
                }

                if !favorites.isEmpty {
                    Section("Favourites") {
                        ForEach(favorites) { entry in
                            foodRow(entry, key: "favourite-\(entry.matchKey)")
                        }
                    }
                }

                if !recents.isEmpty {
                    Section {
                        ForEach(recents) { entry in
                            foodRow(entry, key: "recent-\(entry.matchKey)")
                        }
                    } header: {
                        Text("Recent")
                    } footer: {
                        Text("Tip: swipe right on any meal in Today or History to star it as a favourite.")
                    }
                }

                Section {
                    Button("Enter details by hand", systemImage: "square.and.pencil") {
                        isAddingManually = true
                    }
                }
            }
            .navigationTitle("Add Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $describing) { meal in
                AnalysisView(description: meal) { dismiss() }
            }
            .sheet(isPresented: $isAddingManually) {
                EntryFormView { dismiss() }
            }
            .sensoryFeedback(.success, trigger: addCount)
        }
    }

    private func foodRow(_ entry: FoodEntry, key: String) -> some View {
        QuickAddRow(
            title: entry.name,
            detail: [entry.portion, "\(entry.calories.formatted()) kcal"].compactMap { $0 }.joined(separator: " · "),
            thumbnail: entry.thumbnail,
            isAdded: added.contains(key)
        ) {
            EntryActions.logAgain(entry, context: modelContext)
            markAdded(key)
        }
    }

    private func markAdded(_ key: String) {
        added.insert(key)
        addCount += 1
    }

    private func unique(_ entries: [FoodEntry]) -> [FoodEntry] {
        var seen: Set<String> = []
        return entries.filter { seen.insert($0.matchKey).inserted }
    }
}

/// A food or meal with a + button. Tapping adds it; a tick shows it was added.
private struct QuickAddRow: View {
    let title: String
    let detail: String
    let thumbnail: Data?
    let isAdded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let thumbnail, let image = UIImage(data: thumbnail) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(.rect(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isAdded ? Color.green : Color.accentColor)
                    .contentTransition(.symbolEffect(.replace))
            }
            .contentShape(Rectangle())
        }
        .accessibilityHint(isAdded ? "Added. Tap to add again." : "Adds it to today")
    }
}

#Preview {
    QuickAddView()
        .modelContainer(for: [FoodEntry.self, WeightEntry.self, WaterLog.self], inMemory: true)
}
