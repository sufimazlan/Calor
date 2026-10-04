//
//  BackupManager.swift
//  Calor
//

import Foundation
import SwiftData

/// Everything needed to rebuild Calor on a phone: meals, profile, targets and settings.
/// Saved as JSON, one file per day.
struct CalorBackup: Codable {
    struct Entry: Codable {
        var id: UUID
        var timestamp: Date
        var mealType: String
        var name: String
        var portion: String?
        var calories: Int
        var proteinG: Double?
        var carbsG: Double?
        var fatG: Double?
        var source: String
        var confidence: String?
        var notes: String?
        var thumbnail: Data?
    }

    var version: Int
    var createdAt: Date
    var profile: Profile?
    var userName: String
    var avatarJPEG: Data?
    var dailyGoalKcal: Int
    var proteinTargetG: Int
    var carbsTargetG: Int
    var fatTargetG: Int
    var rolloverEnabled: Bool
    var remindersEnabled: Bool
    var breakfastReminderMinutes: Int
    var lunchReminderMinutes: Int
    var dinnerReminderMinutes: Int
    var entries: [Entry]
}

/// Automatic backups to a folder the user picks once in the Files app,
/// e.g. "On My iPhone/Calor Backups". Files there stay on the phone even if
/// Calor is deleted. Each phone backs up to its own storage.
enum BackupManager {
    static let filePrefix = "Calor backup "
    /// Daily backups to keep; older ones are deleted.
    static let keepCount = 7

    enum BackupError: LocalizedError {
        case noFolder
        case folderUnavailable

        var errorDescription: String? {
            switch self {
            case .noFolder: "No backup folder chosen."
            case .folderUnavailable: "The backup folder can't be opened. It may have been moved or deleted. Choose it again."
            }
        }
    }

    // MARK: - Folder

    /// Remembers a folder picked with the file importer, so backups can be
    /// written there later without asking again.
    static func setFolder(_ url: URL) throws {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let defaults = UserDefaults.standard
        defaults.set(bookmark, forKey: SettingsKey.backupFolderBookmark)
        defaults.set("", forKey: SettingsKey.backupLastError)
    }

    static var hasFolder: Bool {
        UserDefaults.standard.data(forKey: SettingsKey.backupFolderBookmark) != nil
    }

    /// The saved folder, or nil if none was chosen or it can't be found.
    /// Pass `refreshIfStale: false` from views, which mustn't write settings while drawing.
    static func folderURL(refreshIfStale: Bool = true) -> URL? {
        guard let bookmark = UserDefaults.standard.data(forKey: SettingsKey.backupFolderBookmark) else {
            return nil
        }
        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else {
            return nil
        }
        if isStale && refreshIfStale {
            // The folder moved or was renamed; refresh the bookmark so it keeps working.
            let isAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if isAccessing { url.stopAccessingSecurityScopedResource() }
            }
            if let fresh = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil) {
                UserDefaults.standard.set(fresh, forKey: SettingsKey.backupFolderBookmark)
            }
        }
        return url
    }

    static var lastBackupDate: Date? {
        let seconds = UserDefaults.standard.double(forKey: SettingsKey.backupLastDate)
        return seconds > 0 ? Date(timeIntervalSince1970: seconds) : nil
    }

    // MARK: - Backing up

    /// When Calor last backed up on leaving (this launch only).
    private static var lastLeaveBackup: Date?

    /// Backs up when the app opens, if a folder is set and the last backup is
    /// older than `minimumAge` or from an earlier day.
    static func backUpIfNeeded(context: ModelContext, minimumAge: TimeInterval) {
        guard hasFolder else { return }
        if let last = lastBackupDate,
           Calendar.current.isDateInToday(last),
           Date.now.timeIntervalSince(last) < minimumAge {
            return
        }
        backUpRecordingErrors(context: context)
    }

    /// Backs up when the app goes to the background, at most every 15 minutes.
    /// Not held back by the backup made on opening, so a short session's meals are saved.
    static func backUpOnLeave(context: ModelContext) {
        guard hasFolder else { return }
        if let last = lastLeaveBackup, Date.now.timeIntervalSince(last) < 15 * 60 { return }
        backUpRecordingErrors(context: context)
        lastLeaveBackup = .now
    }

    /// Automatic backups can't show an alert, so failures are saved for Today and Settings to show.
    private static func backUpRecordingErrors(context: ModelContext) {
        do {
            try backUpNow(context: context)
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: SettingsKey.backupLastError)
        }
    }

    /// Writes today's backup file (replacing an earlier one from today)
    /// and deletes all but the newest `keepCount` daily backups.
    /// Returns false, writing nothing, if the phone has no meals: right after a
    /// reinstall that must never replace a real backup.
    @discardableResult
    static func backUpNow(context: ModelContext) throws -> Bool {
        guard let folder = folderURL() else {
            throw hasFolder ? BackupError.folderUnavailable : BackupError.noFolder
        }
        guard folder.startAccessingSecurityScopedResource() else {
            throw BackupError.folderUnavailable
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        let backup = try makeBackup(context: context)
        guard !backup.entries.isEmpty else { return false }

        let target = folder.appendingPathComponent(fileName(for: .now))
        if lastBackupDate == nil, FileManager.default.fileExists(atPath: target.path) {
            // This install has never backed up, so today's file came from before a
            // reinstall. Keep it under another name (keep-last-7 leaves it alone).
            let kept = folder.appendingPathComponent(
                target.deletingPathExtension().lastPathComponent + " (earlier install).json")
            try? FileManager.default.removeItem(at: kept)
            try FileManager.default.moveItem(at: target, to: kept)
        }
        try encoder.encode(backup).write(to: target, options: .atomic)
        deleteOldBackups(in: folder)

        let defaults = UserDefaults.standard
        defaults.set(Date.now.timeIntervalSince1970, forKey: SettingsKey.backupLastDate)
        defaults.set("", forKey: SettingsKey.backupLastError)
        return true
    }

    /// The newest daily backup in the chosen folder, if any. Used to offer a
    /// restore when the folder is picked again after a reinstall.
    static func newestBackup() -> CalorBackup? {
        guard let folder = folderURL() else { return nil }
        guard folder.startAccessingSecurityScopedResource() else { return nil }
        defer { folder.stopAccessingSecurityScopedResource() }
        guard let newest = dailyBackups(in: folder).first,
              let data = try? Data(contentsOf: newest) else { return nil }
        return try? decoder.decode(CalorBackup.self, from: data)
    }

    static func fileName(for date: Date) -> String {
        // Local time zone, so a backup made at 7am in Malaysia gets today's date, not yesterday's (UTC).
        "\(filePrefix)\(date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())).json"
    }

    /// Files named exactly "Calor backup YYYY-MM-DD.json", newest first. Renamed
    /// copies, duplicates and "earlier install" files don't count and are never deleted.
    private static func dailyBackups(in folder: URL) -> [URL] {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.lastPathComponent.wholeMatch(of: #/Calor backup \d{4}-\d{2}-\d{2}\.json/#) != nil }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
    }

    private static func deleteOldBackups(in folder: URL) {
        for old in dailyBackups(in: folder).dropFirst(keepCount) {
            try? FileManager.default.removeItem(at: old)
        }
    }

    private static func makeBackup(context: ModelContext) throws -> CalorBackup {
        let defaults = UserDefaults.standard
        let includePhotos = defaults.object(forKey: SettingsKey.backupIncludesPhotos) as? Bool ?? true
        let entries = try context.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.timestamp)]))

        func integer(_ key: String, default value: Int) -> Int {
            defaults.object(forKey: key) as? Int ?? value
        }

        return CalorBackup(
            version: 1,
            createdAt: .now,
            profile: Profile(data: defaults.data(forKey: SettingsKey.profile)),
            userName: defaults.string(forKey: SettingsKey.userName) ?? "",
            avatarJPEG: defaults.data(forKey: SettingsKey.avatarJPEG),
            dailyGoalKcal: integer(SettingsKey.dailyGoalKcal, default: SettingsKey.defaultDailyGoal),
            proteinTargetG: integer(SettingsKey.proteinTargetG, default: 0),
            carbsTargetG: integer(SettingsKey.carbsTargetG, default: 0),
            fatTargetG: integer(SettingsKey.fatTargetG, default: 0),
            rolloverEnabled: defaults.bool(forKey: SettingsKey.rolloverEnabled),
            remindersEnabled: defaults.bool(forKey: SettingsKey.remindersEnabled),
            breakfastReminderMinutes: MealReminders.minutes(for: MealReminders.all[0]),
            lunchReminderMinutes: MealReminders.minutes(for: MealReminders.all[1]),
            dinnerReminderMinutes: MealReminders.minutes(for: MealReminders.all[2]),
            entries: entries.map { entry in
                CalorBackup.Entry(
                    id: entry.id,
                    timestamp: entry.timestamp,
                    mealType: entry.mealTypeRaw,
                    name: entry.name,
                    portion: entry.portion,
                    calories: entry.calories,
                    proteinG: entry.proteinG,
                    carbsG: entry.carbsG,
                    fatG: entry.fatG,
                    source: entry.sourceRaw,
                    confidence: entry.confidenceRaw,
                    notes: entry.notes,
                    thumbnail: includePhotos ? entry.thumbnail : nil
                )
            }
        )
    }

    // MARK: - Restoring

    /// Reads a backup file picked with the file importer.
    static func readBackup(from url: URL) throws -> CalorBackup {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        return try decoder.decode(CalorBackup.self, from: Data(contentsOf: url))
    }

    /// Copy of what was on the phone before the last restore. Never deleted automatically.
    static let beforeRestoreFileName = "Calor before restore.json"

    /// Replaces every meal and setting on this phone with the backup.
    /// What was there before is first saved as "Calor before restore.json".
    static func restore(_ backup: CalorBackup, context: ModelContext) throws {
        try saveCopyBeforeRestore(context: context)

        // Delete through the context (not a batch delete) so the change and the
        // inserts are saved together, and can be undone if saving fails.
        for old in try context.fetch(FetchDescriptor<FoodEntry>()) {
            context.delete(old)
        }
        for saved in backup.entries {
            let entry = FoodEntry(
                timestamp: saved.timestamp,
                mealType: MealType(rawValue: saved.mealType) ?? .snack,
                name: saved.name,
                portion: saved.portion,
                calories: saved.calories,
                proteinG: saved.proteinG,
                carbsG: saved.carbsG,
                fatG: saved.fatG,
                source: EntrySource(rawValue: saved.source) ?? .manual,
                confidence: saved.confidence.flatMap(Confidence.init(rawValue:)),
                thumbnail: saved.thumbnail,
                notes: saved.notes
            )
            entry.id = saved.id
            context.insert(entry)
        }
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }

        let defaults = UserDefaults.standard
        if let profileData = backup.profile?.data {
            defaults.set(profileData, forKey: SettingsKey.profile)
        }
        defaults.set(backup.userName, forKey: SettingsKey.userName)
        defaults.set(backup.avatarJPEG, forKey: SettingsKey.avatarJPEG)
        defaults.set(backup.dailyGoalKcal, forKey: SettingsKey.dailyGoalKcal)
        defaults.set(backup.proteinTargetG, forKey: SettingsKey.proteinTargetG)
        defaults.set(backup.carbsTargetG, forKey: SettingsKey.carbsTargetG)
        defaults.set(backup.fatTargetG, forKey: SettingsKey.fatTargetG)
        defaults.set(backup.rolloverEnabled, forKey: SettingsKey.rolloverEnabled)
        defaults.set(backup.remindersEnabled, forKey: SettingsKey.remindersEnabled)
        defaults.set(backup.breakfastReminderMinutes, forKey: SettingsKey.breakfastReminderMinutes)
        defaults.set(backup.lunchReminderMinutes, forKey: SettingsKey.lunchReminderMinutes)
        defaults.set(backup.dinnerReminderMinutes, forKey: SettingsKey.dinnerReminderMinutes)
        // Treat the restored data as this install's latest backup, so the next
        // automatic backup writes today's file normally.
        defaults.set(Date.now.timeIntervalSince1970, forKey: SettingsKey.backupLastDate)
    }

    private static func saveCopyBeforeRestore(context: ModelContext) throws {
        guard let folder = folderURL() else { return }
        guard folder.startAccessingSecurityScopedResource() else { return }
        defer { folder.stopAccessingSecurityScopedResource() }
        let current = try makeBackup(context: context)
        guard !current.entries.isEmpty else { return }
        try encoder.encode(current).write(to: folder.appendingPathComponent(beforeRestoreFileName), options: .atomic)
    }

    // MARK: - Coding

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
