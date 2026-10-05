//
//  MoreSettingsSections.swift
//  Calor
//

import SwiftUI
import SwiftData
import UIKit

/// Apple Health: workout calories for today's goal, and weight both ways.
struct HealthSettingsSection: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.healthEnabled) private var isEnabled = false
    @AppStorage(SettingsKey.healthWorkoutShare) private var workoutShare = 0
    @AppStorage(SettingsKey.healthWritesWeight) private var writesWeight = true
    @AppStorage(SettingsKey.healthReadsWeight) private var readsWeight = true
    @State private var isConnecting = false
    @State private var message: String?

    var body: some View {
        Section {
            if HealthService.isAvailable {
                Toggle("Connect Apple Health", isOn: connectionBinding)
                    .disabled(isConnecting)
                if isEnabled {
                    Picker("Add workout calories", selection: $workoutShare) {
                        Text("Off").tag(0)
                        Text("Half").tag(50)
                        Text("All").tag(100)
                    }
                    Toggle("Save weigh-ins to Health", isOn: $writesWeight)
                    Toggle("Import weight from Health", isOn: $readsWeight)
                        .onChange(of: readsWeight) { _, isOn in
                            if isOn {
                                Task { await WeightLog.importFromHealth(context: modelContext) }
                            }
                        }
                }
            } else {
                Text("Apple Health isn't available on this device.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Apple Health")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let message {
                    Text(message)
                        .foregroundStyle(.red)
                }
                Text("Workouts from Apple Health (for example an Apple Watch) can raise today's goal. Your goal already allows for your usual workouts, so adding them all may count them twice: Half is a safe middle. Weights from a smart scale come in automatically.")
            }
        }
    }

    private var connectionBinding: Binding<Bool> {
        Binding(get: { isEnabled }, set: { isOn in
            if isOn {
                Task { await connect() }
            } else {
                isEnabled = false
            }
        })
    }

    private func connect() async {
        isConnecting = true
        defer { isConnecting = false }
        do {
            try await HealthService.requestAccess()
            isEnabled = true
            message = nil
            await WeightLog.importFromHealth(context: modelContext)
        } catch {
            isEnabled = false
            message = "Apple Health couldn't be connected. \(error.localizedDescription)"
        }
    }
}

/// Exports meals and daily totals as CSV files for Numbers, Excel or Google Sheets.
struct ExportSection: View {
    @Environment(\.modelContext) private var modelContext
    @State private var export: ExportFiles?
    @State private var errorText: String?

    struct ExportFiles: Identifiable {
        let id = UUID()
        let urls: [URL]
    }

    var body: some View {
        Section {
            Button("Export as CSV", systemImage: "square.and.arrow.up") {
                do {
                    export = ExportFiles(urls: try DataExport.makeFiles(context: modelContext))
                    errorText = nil
                } catch {
                    errorText = "Export failed: \(error.localizedDescription)"
                }
            }
            .sheet(item: $export) { files in
                ShareSheet(items: files.urls)
                    .presentationDetents([.medium, .large])
            }
        } header: {
            Text("Export")
        } footer: {
            Text(errorText ?? "Two spreadsheet files: every meal, and one row per day with totals, water and weight. Save them to Files, AirDrop them, or email them.")
        }
    }
}

/// iOS's share sheet, which SwiftUI doesn't offer for several files at once.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    Form {
        HealthSettingsSection()
        ExportSection()
    }
    .modelContainer(for: [FoodEntry.self, WeightEntry.self, WaterLog.self], inMemory: true)
}
