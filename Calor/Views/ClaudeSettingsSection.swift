//
//  ClaudeSettingsSection.swift
//  Calor
//

import SwiftUI

/// Settings for Claude photo analysis: the API key (kept in the Keychain),
/// the model, this phone's monthly limit and what it has spent.
struct ClaudeSettingsSection: View {
    @AppStorage(SettingsKey.aiModel) private var modelRaw = ClaudeModel.haiku.rawValue
    @AppStorage(SettingsKey.aiMonthlyLimitUSD) private var monthlyLimit = AIBudget.maxMonthlyLimit
    @AppStorage(SettingsKey.analysisAsksForNote) private var asksForNote = true

    @State private var savedKey = KeychainStore.apiKey
    @State private var keyInput = ""
    @State private var isChecking = false
    @State private var isConfirmingRemoval = false
    @State private var message: String?
    @State private var messageIsError = false

    private var model: ClaudeModel {
        ClaudeModel(rawValue: modelRaw) ?? .haiku
    }

    var body: some View {
        Section {
            if let savedKey {
                LabeledContent("API key", value: KeychainStore.masked(savedKey))
                Picker("Model", selection: $modelRaw) {
                    ForEach(ClaudeModel.allCases) { model in
                        Text(model.title).tag(model.rawValue)
                    }
                }
                Stepper(value: $monthlyLimit, in: AIBudget.minMonthlyLimit...AIBudget.maxMonthlyLimit, step: 0.5) {
                    LabeledContent("Monthly limit", value: AIBudget.money(monthlyLimit))
                }
                usage
                Toggle("Add a note before analysing", isOn: $asksForNote)
                Button("Remove API key", role: .destructive) {
                    isConfirmingRemoval = true
                }
                .confirmationDialog("Remove the API key from this iPhone?", isPresented: $isConfirmingRemoval,
                                    titleVisibility: .visible) {
                    Button("Remove key", role: .destructive, action: removeKey)
                } message: {
                    Text("Photos go back to demo results until you add a key again.")
                }
            } else {
                SecureField("Paste API key (sk-ant-…)", text: $keyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button {
                    Task { await checkAndSaveKey() }
                } label: {
                    if isChecking {
                        ProgressView()
                    } else {
                        Text("Check and save key")
                    }
                }
                .disabled(trimmedKey.isEmpty || isChecking)
                Toggle("Add a note before analysing", isOn: $asksForNote)
            }
        } header: {
            Text("Photo analysis")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let message {
                    Text(message)
                        .foregroundStyle(messageIsError ? Color.red : Color.secondary)
                }
                Text(savedKey == nil ? Self.setupText : activeText)
            }
        }
    }

    private var usage: some View {
        let budget = AIBudget()
        let spent = budget.spentThisMonth
        let share = min(spent / max(monthlyLimit, 0.01), 1)
        return VStack(alignment: .leading, spacing: 6) {
            LabeledContent("Used this month", value: "\(AIBudget.money(spent)) of \(AIBudget.money(monthlyLimit))")
            ProgressView(value: share)
                .tint(share > 0.8 ? Color.orange : Color.accentColor)
            Text("\(budget.analysesThisMonth) analyses this month · \(budget.analysesToday) of \(AIBudget.dailyLimit) today")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var trimmedKey: String {
        keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let setupText = "Without a key, photos get sample results (demo mode). To turn on real analysis: in the Claude Console (platform.claude.com), create a workspace for Calor with a US$10 monthly spend limit, create an API key in it, and paste it here. Use a separate key on each phone. The key is kept in this iPhone's Keychain."

    private var activeText: String {
        var text = "\(model.title): \(model.detail) Photos are made small before they're sent, and only when you analyse them. This phone stops at its monthly limit (at most \(AIBudget.money(AIBudget.maxMonthlyLimit))) and at \(AIBudget.dailyLimit) analyses a day. The Console's US$10 spend limit is the hard cap for both phones."
        if model == .sonnet {
            text += " If Sonnet 5.5 declines a request, the API can pass it to another Claude model in the same call."
        }
        return text
    }

    private func checkAndSaveKey() async {
        let key = trimmedKey
        isChecking = true
        defer { isChecking = false }
        switch await ClaudeKeyCheck.check(key) {
        case .valid:
            do {
                try KeychainStore.saveAPIKey(key)
                savedKey = key
                keyInput = ""
                show("Key saved. Photos now go to Claude.", isError: false)
            } catch {
                show(error.localizedDescription, isError: true)
            }
        case .invalid:
            show("That key wasn't accepted. Copy it again from the Claude Console.", isError: true)
        case .failed(let reason):
            show("Couldn't check the key. \(reason)", isError: true)
        }
    }

    private func removeKey() {
        KeychainStore.deleteAPIKey()
        savedKey = nil
        show("Key removed. Photos get sample results.", isError: false)
    }

    private func show(_ text: String, isError: Bool) {
        message = text
        messageIsError = isError
    }
}

#Preview {
    Form {
        ClaudeSettingsSection()
    }
}
