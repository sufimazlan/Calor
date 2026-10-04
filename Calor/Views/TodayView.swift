//
//  TodayView.swift
//  Calor
//

import SwiftUI
import SwiftData

/// Home screen: today's total against the goal, and today's entries grouped by meal.
struct TodayView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var day = Calendar.current.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            DayLog(day: day)
                .navigationTitle("Today")
        }
        // Roll over to the new day if the app was left open past midnight.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                day = Calendar.current.startOfDay(for: .now)
            }
        }
    }
}

private struct DayLog: View {
    let day: Date

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal
    @Query private var entries: [FoodEntry]

    @State private var isAddingEntry = false
    @State private var isShowingSettings = false
    @State private var editingEntry: FoodEntry?

    init(day: Date) {
        self.day = day
        let start = day
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        _entries = Query(
            filter: #Predicate<FoodEntry> { $0.timestamp >= start && $0.timestamp < end },
            sort: \FoodEntry.timestamp
        )
    }

    private var totalCalories: Int {
        entries.reduce(0) { $0 + $1.calories }
    }

    var body: some View {
        List {
            Section {
                CalorieSummary(eaten: totalCalories, goal: dailyGoal)
                    .frame(maxWidth: .infinity)
            } header: {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
            }

            if entries.isEmpty {
                Section {
                    Text("Nothing logged yet today.")
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(MealType.allCases) { meal in
                let mealEntries = entries.filter { $0.mealType == meal }
                if !mealEntries.isEmpty {
                    Section {
                        ForEach(mealEntries) { entry in
                            Button {
                                editingEntry = entry
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .tint(.primary)
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                modelContext.delete(mealEntries[index])
                            }
                        }
                    } header: {
                        HStack {
                            Text(meal.title)
                            Spacer()
                            Text("\(mealEntries.reduce(0) { $0 + $1.calories }.formatted()) kcal")
                        }
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            // "Snap meal" joins this button in milestone 3.
            Button {
                isAddingEntry = true
            } label: {
                Label("Add manually", systemImage: "square.and.pencil")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings", systemImage: "gearshape") {
                    isShowingSettings = true
                }
            }
        }
        .sheet(isPresented: $isAddingEntry) {
            EntryFormView()
        }
        .sheet(item: $editingEntry) { entry in
            EntryFormView(entry: entry)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
    }
}

#Preview {
    let container = try! ModelContainer(
        for: FoodEntry.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    container.mainContext.insert(FoodEntry(mealType: .breakfast, name: "Roti canai with dhal", portion: "2 pieces", calories: 600))
    container.mainContext.insert(FoodEntry(mealType: .breakfast, name: "Teh tarik", portion: "1 cup", calories: 150))
    container.mainContext.insert(FoodEntry(mealType: .lunch, name: "Nasi lemak with fried chicken", portion: "1 plate", calories: 800))
    return TodayView()
        .modelContainer(container)
}
