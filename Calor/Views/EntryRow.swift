//
//  EntryRow.swift
//  Calor
//

import SwiftUI
import SwiftData
import UIKit

/// One food entry in a list, with the meal photo if there is one.
struct EntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            if let data = entry.thumbnail, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(.rect(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.name)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .accessibilityLabel("Favourite")
                    }
                }
                if let portion = entry.portion {
                    Text(portion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let score = entry.healthScore {
                HealthScoreBadge(score: score)
            }
            Text("\(entry.calories.formatted()) kcal")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// An entry row with its actions: tap to edit, swipe right to log it again or
/// star it, swipe left to delete. Long-press shows the same actions.
struct LoggedEntryRow: View {
    let entry: FoodEntry
    let onEdit: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var loggedAgain = 0

    var body: some View {
        Button(action: onEdit) {
            EntryRow(entry: entry)
        }
        .tint(.primary)
        .swipeActions(edge: .leading) {
            Button("Log again", systemImage: "arrow.clockwise", action: logAgain)
                .tint(.green)
            favoriteButton
                .tint(.yellow)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", systemImage: "trash", role: .destructive) {
                modelContext.delete(entry)
            }
        }
        .contextMenu {
            Button("Log again now", systemImage: "arrow.clockwise", action: logAgain)
            favoriteButton
            Button("Edit", systemImage: "pencil", action: onEdit)
            Button("Delete", systemImage: "trash", role: .destructive) {
                modelContext.delete(entry)
            }
        }
        .sensoryFeedback(.success, trigger: loggedAgain)
    }

    private var favoriteButton: some View {
        Button(entry.isFavorite ? "Unstar" : "Favourite", systemImage: entry.isFavorite ? "star.slash" : "star") {
            EntryActions.toggleFavorite(entry, context: modelContext)
        }
    }

    private func logAgain() {
        EntryActions.logAgain(entry, context: modelContext)
        loggedAgain += 1
    }
}

/// "Log again", "Copy to today" and favourites, shared by Today, History and Add.
enum EntryActions {
    /// Logs the same food again now, as the meal it's time for.
    static func logAgain(_ entry: FoodEntry, context: ModelContext) {
        context.insert(entry.duplicate(mealType: .suggested()))
    }

    /// Copies a whole meal to today, keeping it as the same meal (e.g. yesterday's breakfast).
    static func copyToToday(_ entries: [FoodEntry], context: ModelContext) {
        let now = Date.now
        for entry in entries {
            context.insert(entry.duplicate(at: now))
        }
    }

    /// Starring adds the food to Favourites. Unstarring removes it, including
    /// any other starred entries of the same food.
    static func toggleFavorite(_ entry: FoodEntry, context: ModelContext) {
        guard entry.isFavorite else {
            entry.isFavorite = true
            return
        }
        let key = entry.matchKey
        let starred = (try? context.fetch(FetchDescriptor<FoodEntry>(predicate: #Predicate<FoodEntry> { $0.isFavorite == true }))) ?? []
        for item in starred where item.matchKey == key {
            item.isFavorite = false
        }
        entry.isFavorite = false
    }
}

/// Health score as a small coloured number: green 7–10, orange 4–6, red 1–3.
struct HealthScoreBadge: View {
    let score: Int

    var body: some View {
        Text("\(score)")
            .font(.caption2.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(minWidth: 18, minHeight: 18)
            .padding(.horizontal, 2)
            .background(Self.color(for: score), in: Capsule())
            .accessibilityLabel("Health score \(score) of 10")
    }

    static func color(for score: Int) -> Color {
        switch score {
        case 7...: .green
        case 4...6: .orange
        default: .red
        }
    }
}
