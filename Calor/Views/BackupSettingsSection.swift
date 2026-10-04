//
//  BackupSettingsSection.swift
//  Calor
//

import SwiftUI
import SwiftData
import Observation
import UniformTypeIdentifiers
import UserNotifications

/// Picking the backup folder and restoring a backup. Shared by the backup section
/// (which starts things) and `.backupFlowPresenter` on the screen's Form (which
/// shows the file picker and dialogs). On a row inside a Form they might not appear,
/// because rows that are scrolled off screen aren't loaded.
@Observable
final class BackupFlow {
    enum ImportMode {
        case folder, restore
    }

    var isImporting = false
    var importMode = ImportMode.folder
    var pendingRestore: CalorBackup?
    /// Meals already on this phone that were added to `pendingRestore` (after a reinstall).
    var mergedMealCount = 0
    var message: String?

    func pickFolder() {
        importMode = .folder
        isImporting = true
    }

    func pickRestoreFile() {
        importMode = .restore
        isImporting = true
    }

    func cancelRestore() {
        pendingRestore = nil
    }

    func handleImport(_ result: Result<URL, Error>, context: ModelContext) {
        message = nil
        switch result {
        case .failure(let error):
            message = error.localizedDescription
        case .success(let url):
            switch importMode {
            case .folder:
                useFolder(url, context: context)
            case .restore:
                do {
                    mergedMealCount = 0
                    pendingRestore = try BackupManager.readBackup(from: url)
                } catch {
                    message = "That file isn't a Calor backup."
                }
            }
        }
    }

    private func useFolder(_ url: URL, context: ModelContext) {
        let previousPath = BackupManager.folderURL(refreshIfStale: false)?.standardizedFileURL.path
        do {
            try BackupManager.setFolder(url)
        } catch {
            setError("Couldn't use that folder: \(error.localizedDescription)")
            return
        }
        // A different folder may hold another install's backups. Treat it like a first
        // backup on this install, so its newest file is kept and offered below.
        if previousPath != url.standardizedFileURL.path {
            UserDefaults.standard.removeObject(forKey: SettingsKey.backupLastDate)
        }
        // After a reinstall the folder may already hold a backup with more meals than
        // this phone has: offer to restore it, keeping meals logged on this phone.
        if BackupManager.lastBackupDate == nil, let newest = BackupManager.newestBackup() {
            let mealsHere = (try? context.fetchCount(FetchDescriptor<FoodEntry>())) ?? 0
            if newest.entries.count > mealsHere {
                let merged = BackupManager.merging(newest, withMealsIn: context)
                mergedMealCount = merged.entries.count - newest.entries.count
                pendingRestore = merged
                return
            }
        }
        backUpNow(context: context)
    }

    func backUpNow(context: ModelContext) {
        do {
            let didWrite = try BackupManager.backUpNow(context: context)
            message = didWrite
                ? "Backed up just now."
                : "Nothing to back up yet. Log a meal first. Existing backups were left alone."
        } catch {
            message = nil
            setError(error.localizedDescription)
        }
    }

    func restore(_ backup: CalorBackup, context: ModelContext) {
        do {
            try BackupManager.restore(backup, context: context)
            message = "Restored \(backup.entries.count) meals."
            Task { await MealReminders.applyRestoredSettings() }
        } catch {
            message = "Restore didn't happen, nothing was changed. \(error.localizedDescription)"
        }
        cancelRestore()
    }

    /// Explains exactly what a restore will do, including whether meals already on this phone are kept.
    func restoreMessage(for backup: CalorBackup) -> String {
        func meals(_ count: Int) -> String { count == 1 ? "1 meal" : "\(count) meals" }
        let date = backup.createdAt.formatted(date: .abbreviated, time: .shortened)
        let safety: String
        if BackupManager.folderURL(refreshIfStale: false) != nil {
            safety = "If this phone has meals, they're saved first as a \"\(BackupManager.beforeRestorePrefix) …\" file in your backup folder."
        } else if BackupManager.hasFolder {
            safety = "Your backup folder can't be opened right now, so if this phone has meals the restore will stop to keep them safe."
        } else {
            safety = "If this phone has meals, choose a backup folder first so they can be saved before they're replaced."
        }
        if mergedMealCount > 0 {
            let backupMeals = backup.entries.count - mergedMealCount
            return "This folder has a backup from \(date) with \(meals(backupMeals)). Restoring it keeps the \(meals(mergedMealCount)) logged on this phone since, and brings back your profile and settings. \(safety)"
        }
        return "Backup from \(date) with \(meals(backup.entries.count)). All meals and settings on this phone will be replaced. \(safety)"
    }

    private func setError(_ text: String) {
        UserDefaults.standard.set(text, forKey: SettingsKey.backupLastError)
    }
}

/// Shows the file picker and restore dialog for a `BackupFlow`. Attach to the Form.
struct BackupFlowPresenter: ViewModifier {
    @Bindable var flow: BackupFlow
    @Environment(\.modelContext) private var modelContext

    func body(content: Content) -> some View {
        content
            .fileImporter(isPresented: $flow.isImporting,
                          allowedContentTypes: flow.importMode == .folder ? [.folder] : [.json]) { result in
                flow.handleImport(result, context: modelContext)
            }
            .confirmationDialog(flow.mergedMealCount > 0 ? "Restore your backup?" : "Restore this backup?",
                                isPresented: restoreDialogBinding,
                                titleVisibility: .visible,
                                presenting: flow.pendingRestore) { backup in
                Button(flow.mergedMealCount > 0 ? "Restore and keep this phone's meals" : "Replace everything on this phone",
                       role: flow.mergedMealCount > 0 ? nil : .destructive) {
                    flow.restore(backup, context: modelContext)
                }
            } message: { backup in
                Text(flow.restoreMessage(for: backup))
            }
    }

    private var restoreDialogBinding: Binding<Bool> {
        Binding(get: { flow.pendingRestore != nil },
                set: { if !$0 { flow.cancelRestore() } })
    }
}

extension View {
    func backupFlowPresenter(_ flow: BackupFlow) -> some View {
        modifier(BackupFlowPresenter(flow: flow))
    }
}

/// Settings section for automatic backup: pick a folder once, see the last
/// backup, back up now, and restore.
struct BackupSettingsSection: View {
    let flow: BackupFlow

    @Environment(\.modelContext) private var modelContext
    @AppStorage(SettingsKey.backupFolderBookmark) private var folderBookmark: Data?
    @AppStorage(SettingsKey.backupLastDate) private var lastBackupSeconds = 0.0
    @AppStorage(SettingsKey.backupLastError) private var lastError = ""
    @AppStorage(SettingsKey.backupIncludesPhotos) private var includesPhotos = true

    var body: some View {
        // Resolved once per render, without writing settings while drawing.
        let folderName = folderBookmark == nil
            ? nil
            : BackupManager.folderURL(refreshIfStale: false)?.lastPathComponent

        Section {
            if let folderName {
                LabeledContent("Folder", value: folderName)
                LabeledContent("Last backup") {
                    if lastBackupSeconds > 0 {
                        Text(Date(timeIntervalSince1970: lastBackupSeconds), format: .relative(presentation: .named))
                    } else {
                        Text("Not yet")
                    }
                }
                Toggle("Include meal photos", isOn: $includesPhotos)
                Button("Back up now", systemImage: "arrow.clockwise") {
                    flow.backUpNow(context: modelContext)
                }
                Button("Change folder", systemImage: "folder") {
                    flow.pickFolder()
                }
            } else {
                Button("Choose backup folder", systemImage: "folder.badge.plus") {
                    flow.pickFolder()
                }
            }
            Button("Restore from a backup…", systemImage: "clock.arrow.circlepath") {
                flow.pickRestoreFile()
            }
        } header: {
            Text("Automatic backup")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if !lastError.isEmpty {
                    Text(lastError)
                        .foregroundStyle(.red)
                }
                if let message = flow.message {
                    Text(message)
                }
                Text(folderName == nil
                     ? "Pick a folder on this iPhone, for example create \"Calor Backups\" in On My iPhone. Calor then saves a backup there every day and keeps the last \(BackupManager.keepCount). Backups stay even if the app is deleted."
                     : "Saved when you open Calor each day and when you leave it. The last \(BackupManager.keepCount) days are kept. Each phone backs up to its own storage.")
            }
        }
    }
}

/// The backup section on its own, opened from the Today screen.
struct BackupSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = BackupFlow()

    var body: some View {
        NavigationStack {
            Form {
                BackupSettingsSection(flow: flow)
            }
            .backupFlowPresenter(flow)
            .navigationTitle("Backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Settings section showing when this install stops opening (free Apple ID: 7 days),
/// with the reinstall reminders switch.
struct InstallSettingsSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingsKey.reinstallRemindersEnabled) private var reinstallRemindersEnabled = true
    @State private var notificationsDenied = false

    var body: some View {
        Section {
            if let expiry = InstallInfo.expirationDate {
                LabeledContent("This install expires") {
                    Text(expiry.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(InstallInfo.expiresSoon ? Color.orange : Color.secondary)
                }
                Toggle("Remind me to reinstall", isOn: $reinstallRemindersEnabled)
                    .onChange(of: reinstallRemindersEnabled) {
                        Task {
                            await ReinstallReminders.reschedule()
                            await refreshNotificationStatus()
                        }
                    }
                    // Re-checked when coming back from the iPhone Settings app.
                    .task(id: scenePhase) {
                        await refreshNotificationStatus()
                    }
            } else {
                LabeledContent("This install expires", value: "Never (simulator)")
            }
        } header: {
            Text("App install")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if reinstallRemindersEnabled && notificationsDenied {
                    Text("Notifications are turned off for Calor, so these reminders can't arrive. Turn them on in the iPhone Settings app → Notifications → Calor.")
                        .foregroundStyle(.red)
                }
                Text("With a free Apple ID, apps installed from Xcode stop opening after 7 days. Reminders come 1 day and 1 hour before. To reinstall, open Xcode on the Mac and press ⌘R with this iPhone nearby. Your meals are kept.")
            }
        }
    }

    private func refreshNotificationStatus() async {
        notificationsDenied = await UNUserNotificationCenter.current()
            .notificationSettings().authorizationStatus == .denied
    }
}

#Preview {
    @Previewable @State var flow = BackupFlow()
    Form {
        BackupSettingsSection(flow: flow)
        InstallSettingsSection()
    }
    .backupFlowPresenter(flow)
    .modelContainer(for: FoodEntry.self, inMemory: true)
}
