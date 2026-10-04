//
//  SettingsView.swift
//  Calor
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.dailyGoalKcal) private var dailyGoal = SettingsKey.defaultDailyGoal

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $dailyGoal, in: 1000...5000, step: 50) {
                        LabeledContent("Daily goal", value: "\(dailyGoal.formatted()) kcal")
                    }
                } header: {
                    Text("Calories")
                } footer: {
                    Text("Each phone keeps its own goal.")
                }

                Section {
                    LabeledContent("Mode", value: "Demo")
                } header: {
                    Text("Photo analysis")
                } footer: {
                    Text("Photos get sample results for now. Real Claude analysis starts once an API key is added here.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
