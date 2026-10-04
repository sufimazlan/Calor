//
//  BackupSettingsSection.swift
//  Calor
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import UserNotifications

/// Settings section for automatic backup: pick a folder once, see the last
/// backup, back up now, and restore.
struct BackupSettingsSection: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.backupFolderBookmark) private var folderBookmark: Data?
    @AppStorage(SettingsKey.backupLastDate) private var lastBackupSeconds = 0.0
    @AppStorage(SettingsKey.backupLastError) private var lastError = ""
    @AppStorage(SettingsKey.backupIncludesPhotos) private var includesPhotos = true

    private enum ImportMode {
        case folder, restore
    }

    @State private var isImporting = false
    @State private var importMode = ImportMode.folder
    @State private var pendingRestore: CalorBackup?
    @State private var message: String?

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
                    backUpNow()
                }
                Button("Change folder", systemImage: "folder") {
                    pickFolder()
                }
            } else {
                Button("Choose backup folder", systemImage: "folder.badge.plus") {
                    pickFolder()
                }
            }
            // The importer and dialog sit on one row that's always shown: on a whole
            // Section inside a Form they would be repeated for every row.
            Button("Restore from a backup…", systemImage: "clock.arrow.circlepath") {
                importMode = .restore
                isImporting = true
            }
            .fileImporter(isPresented: $isImporting,
                          allowedContentTypes: importMode == .folder ? [.folder] : [.json]) { result in
                handleImport(result)
            }
            .confirmationDialog("Restore this backup?", isPresented: restoreDialogBinding,
                                titleVisibility: .visible, presenting: pendingRestore) { backup in
                Button("Replace everything on this phone", role: .destructive) {
                    restore(backup)
                }
            } message: { backup in
                Text("Backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)) with \(backup.entries.count) meals. All meals and settings on this phone will be replaced. What's here now is saved first as \"\(BackupManager.beforeRestoreFileName)\".")
            }
        } header: {
            Text("Automatic backup")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if !lastError.isEmpty {
                    Text(lastError)
                        .foregroundStyle(.red)
                }
                if let message {
                    Text(message)
                }
                Text(folderName == nil
                     ? "Pick a folder on this iPhone, for example create \"Calor Backups\" in On My iPhone. Calor then saves a backup there every day and keeps the last \(BackupManager.keepCount). Backups stay even if the app is deleted."
                     : "Saved when you open Calor each day and when you leave it. The last \(BackupManager.keepCount) days are kept. Each phone backs up to its own storage.")
            }
        }
    }

    private var restoreDialogBinding: Binding<Bool> {
        Binding(get: { pendingRestore != nil },
                set: { if !$0 { pendingRestore = nil } })
    }

    private func pickFolder() {
        importMode = .folder
        isImporting = true
    }

    private func handleImport(_ result: Result<URL, Error>) {
        message = nil
        switch result {
        case .failure(let error):
            message = error.localizedDescription
        case .success(let url):
            switch importMode {
            case .folder:
                useFolder(url)
            case .restore:
                do {
                    pendingRestore = try BackupManager.readBackup(from: url)
                } catch {
                    message = "That file isn't a Calor backup."
                }
            }
        }
    }

    private func useFolder(_ url: URL) {
        let isFirstBackupOnThisInstall = BackupManager.lastBackupDate == nil
        do {
            try BackupManager.setFolder(url)
        } catch {
            lastError = "Couldn't use that folder: \(error.localizedDescription)"
            return
        }
        // After a reinstall the folder may already hold backups with more meals than
        // this phone has: offer to restore them instead of backing up straight away.
        if isFirstBackupOnThisInstall, let newest = BackupManager.newestBackup() {
            let mealsHere = (try? modelContext.fetchCount(FetchDescriptor<FoodEntry>())) ?? 0
            if newest.entries.count > mealsHere {
                pendingRestore = newest
                return
            }
        }
        backUpNow()
    }

    private func backUpNow() {
        do {
            let didWrite = try BackupManager.backUpNow(context: modelContext)
            message = didWrite
                ? "Backed up just now."
                : "Nothing to back up yet. Log a meal first. Existing backups were left alone."
        } catch {
            message = nil
            lastError = error.localizedDescription
        }
    }

    private func restore(_ backup: CalorBackup) {
        do {
            try BackupManager.restore(backup, context: modelContext)
            message = "Restored \(backup.entries.count) meals."
            Task { await MealReminders.reschedule() }
        } catch {
            message = "Restore failed, nothing was changed: \(error.localizedDescription)"
        }
    }
}

/// Settings section showing when this install stops opening (free Apple ID: 7 days),
/// with the reinstall reminders switch.
struct InstallSettingsSection: View {
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
                        Task { await ReinstallReminders.reschedule() }
                    }
                    .task(id: reinstallRemindersEnabled) {
                        notificationsDenied = await UNUserNotificationCenter.current()
                            .notificationSettings().authorizationStatus == .denied
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
}

#Preview {
    Form {
        BackupSettingsSection()
        InstallSettingsSection()
    }
    .modelContainer(for: FoodEntry.self, inMemory: true)
}
