//
//  TodayView.swift
//  Calor
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Home screen: today's total against the goal, what to do next, and today's
/// entries grouped by meal. Snapping or uploading a photo is the main action.
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
    @AppStorage(SettingsKey.proteinTargetG) private var proteinTarget = 0
    @Query private var entries: [FoodEntry]

    @State private var isAddingEntry = false
    @State private var isShowingSettings = false
    @State private var editingEntry: FoodEntry?

    @State private var isShowingCamera = false
    @State private var capturedImage: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var analysisPhoto: MealPhoto?

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

    private var totalProteinG: Double {
        entries.compactMap(\.proteinG).reduce(0, +)
    }

    private var whatsNext: String {
        Advice.whatsNext(
            eaten: totalCalories,
            goal: dailyGoal,
            proteinG: totalProteinG,
            carbsG: entries.compactMap(\.carbsG).reduce(0, +),
            fatG: entries.compactMap(\.fatG).reduce(0, +),
            proteinTargetG: proteinTarget,
            hasEntries: !entries.isEmpty
        )
    }

    var body: some View {
        List {
            Section {
                CalorieSummary(eaten: totalCalories, goal: dailyGoal,
                               proteinG: Int(totalProteinG.rounded()), proteinTargetG: proteinTarget)
                    .frame(maxWidth: .infinity)
            } header: {
                Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
            }

            Section {
                MacroProgressView(
                    proteinG: totalProteinG,
                    carbsG: entries.compactMap(\.carbsG).reduce(0, +),
                    fatG: entries.compactMap(\.fatG).reduce(0, +),
                    targets: MacroTargets(calorieGoal: dailyGoal, proteinTargetG: proteinTarget)
                )
            } header: {
                Text("Macros")
            } footer: {
                if entries.contains(where: { $0.proteinG == nil }) {
                    Text("Some entries have no macros, so these totals may be low.")
                }
            }

            Section("What's next") {
                Label {
                    Text(whatsNext)
                } icon: {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
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
            photoButtons
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
        .sheet(item: $analysisPhoto) { photo in
            AnalysisView(photo: photo)
        }
        .fullScreenCover(isPresented: $isShowingCamera, onDismiss: analyzeCapturedImage) {
            CameraPicker { capturedImage = $0 }
                .ignoresSafeArea()
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    analysisPhoto = MealPhoto(image: image)
                }
                pickerItem = nil
            }
        }
    }

    /// Snap (camera) and Upload (photo library) are the main actions.
    /// Manual entry is a small fallback for when a photo isn't possible.
    private var photoButtons: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                if CameraPicker.isAvailable {
                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Snap meal", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Upload", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                } else {
                    // The simulator has no camera.
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        Label("Upload meal photo", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .controlSize(.large)

            Button("Add manually instead") {
                isAddingEntry = true
            }
            .font(.footnote)
        }
        .padding()
        .background(.bar)
    }

    private func analyzeCapturedImage() {
        guard let capturedImage else { return }
        analysisPhoto = MealPhoto(image: capturedImage)
        self.capturedImage = nil
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
