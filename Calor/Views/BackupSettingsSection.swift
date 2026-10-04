//
//  BackupSettingsSection.swift
//  Calor
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Settings sections for automatic backup and the 7-day install expiry.
struct BackupSettingsSection: View {
    @Environment(\.modelContext) private var modelContext

    @AppStorage(SettingsKey.backupFolderBookmark) private var folderBookmark: Data?
    @AppStorage(SettingsKey.backupLastDate) private var lastBackupSeconds = 0.0
    @AppStorage(SettingsKey.backupLastError) private var lastError = ""
    @AppStorage(SettingsKey.backupIncludesPhotos) private var includesPhotos = true
    @AppStorage(SettingsKey.reinstallRemindersEnabled) private var reinstallRemindersEnabled = true

    private enum ImportMode {
        case folder, restore
    }

    @State private var isImporting = false
    @State private var importMode = ImportMode.folder
    @State private var pendingRestore: CalorBackup?
    @State private var message: String?

    private var folderName: String? {
        folderBookmark == nil ? nil : BackupManager.folderURL()?.lastPathComponent
    }

    var body: some View {
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
            Button("Restore from a backup…", systemImage: "clock.arrow.circlepath") {
                importMode = .restore
                isImporting = true
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
                     : "Saved each day when you open or leave Calor. The last \(BackupManager.keepCount) days are kept. Each phone backs up to its own storage.")
            }
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
            Text("Backup from \(backup.createdAt.formatted(date: .abbreviated, time: .shortened)) with \(backup.entries.count) meals. All meals and settings on this phone will be replaced.")
        }

        Section {
            if let expiry = InstallInfo.expirationDate {
                LabeledContent("This install expires") {
                    Text(expiry.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(InstallInfo.expiresSoon ? Color.orange : Color.secondary)
                }
                Toggle("Remind me to reinstall", isOn: $reinstallRemindersEnabled)
            } else {
                LabeledContent("This install expires", value: "Never (simulator)")
            }
        } header: {
            Text("App install")
        } footer: {
            Text("With a free Apple ID, apps installed from Xcode stop opening after 7 days. Reminders come 1 day and 1 hour before. To reinstall, open Xcode on the Mac and press ⌘R with this iPhone nearby. Your meals are kept.")
        }
        .onChange(of: reinstallRemindersEnabled) {
            Task { await ReinstallReminders.reschedule() }
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
        switch result {
        case .failure(let error):
            message = error.localizedDescription
        case .success(let url):
            switch importMode {
            case .folder:
                do {
                    try BackupManager.setFolder(url)
                    backUpNow()
                } catch {
                    lastError = "Couldn't use that folder: \(error.localizedDescription)"
                }
            case .restore:
                do {
                    pendingRestore = try BackupManager.readBackup(from: url)
                } catch {
                    message = "That file isn't a Calor backup."
                }
            }
        }
    }

    private func backUpNow() {
        do {
            try BackupManager.backUpNow(context: modelContext)
            message = "Backed up."
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func restore(_ backup: CalorBackup) {
        do {
            try BackupManager.restore(backup, context: modelContext)
            message = "Restored \(backup.entries.count) meals."
            Task { await MealReminders.reschedule() }
        } catch {
            message = "Restore failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    Form {
        BackupSettingsSection()
    }
    .modelContainer(for: FoodEntry.self, inMemory: true)
}
