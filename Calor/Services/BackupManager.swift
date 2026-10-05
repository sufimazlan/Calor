//
//  BackupManager.swift
//  Calor
//

import Foundation
import SwiftData

/// Everything needed to rebuild Calor on a phone: meals, weigh-ins, water,
/// profile, targets and settings. Saved as JSON, one file per day.
/// Fields added after version 1 are optional, so older backups still restore.
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
        var isFavorite: Bool?
        var healthScore: Int?
    }

    struct Weight: Codable {
        var id: UUID
        var date: Date
        var kg: Double
        var source: String
    }

    struct Water: Codable {
        var day: Date
        var glasses: Int
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
    /// Version 2 and later.
    var weights: [Weight]?
    var water: [Water]?
    var waterGoalGlasses: Int?
    var weighInReminderEnabled: Bool?
}

extension CalorBackup.Entry {
    init(_ entry: FoodEntry, includePhoto: Bool) {
        self.init(
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
            thumbnail: includePhoto ? entry.thumbnail : nil,
            isFavorite: entry.isFavorite,
            healthScore: entry.healthScore
        )
    }
}

extension CalorBackup.Weight {
    init(_ entry: WeightEntry) {
        self.init(id: entry.id, date: entry.date, kg: entry.kg, source: entry.sourceRaw)
    }
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
        case noFolderForSafetyCopy

        var errorDescription: String? {
            switch self {
            case .noFolder: "No backup folder chosen."
            case .folderUnavailable: "The backup folder can't be opened. It may have been moved or deleted. Choose it again."
            case .noFolderForSafetyCopy: "Choose a backup folder first, so the meals on this phone can be saved before they're replaced."
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

    /// When Calor last wrote a backup on leaving (this launch only).
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

    /// Backs up every time the app goes to the background (at most once a minute),
    /// so even a short visit's meals are saved. Writing the file is quick.
    static func backUpOnLeave(context: ModelContext) {
        guard hasFolder else { return }
        if let last = lastLeaveBackup, Date.now.timeIntervalSince(last) < 60 { return }
        if backUpRecordingErrors(context: context) {
            lastLeaveBackup = .now
        }
    }

    /// Automatic backups can't show an alert, so failures are saved for Today and Settings to show.
    /// Returns true if a file was written.
    @discardableResult
    private static func backUpRecordingErrors(context: ModelContext) -> Bool {
        do {
            return try backUpNow(context: context)
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: SettingsKey.backupLastError)
            return false
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
        if lastBackupDate == nil, let previous = dailyBackups(in: folder).first {
            // This install has never backed up, so the newest file came from before a
            // reinstall. Keep a copy under a name keep-last-7 never deletes, so the
            // new install's daily backups can't push it out.
            let kept = folder.appendingPathComponent(
                previous.deletingPathExtension().lastPathComponent
                    + " (earlier install \(Int(Date.now.timeIntervalSince1970))).json")
            if previous.lastPathComponent == target.lastPathComponent {
                try FileManager.default.moveItem(at: previous, to: kept)
            } else {
                try FileManager.default.copyItem(at: previous, to: kept)
            }
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

    private static func makeBackup(context: ModelContext, includePhotos forcePhotos: Bool? = nil) throws -> CalorBackup {
        let defaults = UserDefaults.standard
        let includePhotos = forcePhotos ?? (defaults.object(forKey: SettingsKey.backupIncludesPhotos) as? Bool ?? true)
        let entries = try context.fetch(FetchDescriptor<FoodEntry>(sortBy: [SortDescriptor(\.timestamp)]))
        let weights = try context.fetch(FetchDescriptor<WeightEntry>(sortBy: [SortDescriptor(\.date)]))
        let water = try context.fetch(FetchDescriptor<WaterLog>(sortBy: [SortDescriptor(\.day)]))

        func integer(_ key: String, default value: Int) -> Int {
            defaults.object(forKey: key) as? Int ?? value
        }

        return CalorBackup(
            version: 2,
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
            entries: entries.map { CalorBackup.Entry($0, includePhoto: includePhotos) },
            weights: weights.map { CalorBackup.Weight($0) },
            water: water.filter { $0.glasses > 0 }.map { CalorBackup.Water(day: $0.day, glasses: $0.glasses) },
            waterGoalGlasses: integer(SettingsKey.waterGoalGlasses, default: SettingsKey.defaultWaterGoal),
            weighInReminderEnabled: defaults.bool(forKey: SettingsKey.weighInReminderEnabled)
        )
    }

    // MARK: - Restoring

    /// The backup plus any meals, weigh-ins and water on this phone it doesn't
    /// already contain, e.g. logged after a reinstall, so restoring it doesn't lose them.
    static func merging(_ backup: CalorBackup, withMealsIn context: ModelContext) -> CalorBackup {
        var merged = backup
        let known = Set(backup.entries.map(\.id))
        let onPhone = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        merged.entries += onPhone
            .filter { !known.contains($0.id) }
            .map { CalorBackup.Entry($0, includePhoto: true) }

        let knownWeights = Set((backup.weights ?? []).map(\.id))
        let weightsOnPhone = (try? context.fetch(FetchDescriptor<WeightEntry>())) ?? []
        let newWeights = weightsOnPhone.filter { !knownWeights.contains($0.id) }.map { CalorBackup.Weight($0) }
        if backup.weights != nil || !newWeights.isEmpty {
            merged.weights = (backup.weights ?? []) + newWeights
        }

        let calendar = Calendar.current
        let knownDays = Set((backup.water ?? []).map { calendar.startOfDay(for: $0.day) })
        let waterOnPhone = (try? context.fetch(FetchDescriptor<WaterLog>())) ?? []
        let newWater = waterOnPhone
            .filter { $0.glasses > 0 && !knownDays.contains(calendar.startOfDay(for: $0.day)) }
            .map { CalorBackup.Water(day: $0.day, glasses: $0.glasses) }
        if backup.water != nil || !newWater.isEmpty {
            merged.water = (backup.water ?? []) + newWater
        }
        return merged
    }

    /// Reads a backup file picked with the file importer.
    static func readBackup(from url: URL) throws -> CalorBackup {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing { url.stopAccessingSecurityScopedResource() }
        }
        return try decoder.decode(CalorBackup.self, from: Data(contentsOf: url))
    }

    /// Start of the name of the copy saved before each restore. These are never deleted automatically.
    static let beforeRestorePrefix = "Calor before restore"

    /// Replaces every meal and setting on this phone with the backup.
    /// If the phone has meals, they're first saved to the backup folder as
    /// "Calor before restore <time>.json"; if that can't be done, nothing is changed.
    /// Weigh-ins and water are replaced only if the backup has them (version 2 and later),
    /// so restoring an older backup keeps the ones on the phone.
    static func restore(_ backup: CalorBackup, context: ModelContext) throws {
        try saveCopyBeforeRestore(context: context)

        // Delete through the context (not a batch delete) so the change and the
        // inserts are saved together, and can be undone if saving fails.
        for old in try context.fetch(FetchDescriptor<FoodEntry>()) {
            context.delete(old)
        }
        if let weights = backup.weights {
            for old in try context.fetch(FetchDescriptor<WeightEntry>()) {
                context.delete(old)
            }
            for saved in weights {
                let weight = WeightEntry(date: saved.date, kg: saved.kg,
                                         source: WeightSource(rawValue: saved.source) ?? .manual)
                weight.id = saved.id
                context.insert(weight)
            }
        }
        if let water = backup.water {
            for old in try context.fetch(FetchDescriptor<WaterLog>()) {
                context.delete(old)
            }
            for saved in water {
                context.insert(WaterLog(day: Calendar.current.startOfDay(for: saved.day), glasses: saved.glasses))
            }
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
                notes: saved.notes,
                healthScore: saved.healthScore
            )
            entry.id = saved.id
            entry.isFavorite = saved.isFavorite ?? false
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
        if let waterGoal = backup.waterGoalGlasses {
            defaults.set(waterGoal, forKey: SettingsKey.waterGoalGlasses)
        }
        if let weighInReminder = backup.weighInReminderEnabled {
            defaults.set(weighInReminder, forKey: SettingsKey.weighInReminderEnabled)
        }
    }

    private static func saveCopyBeforeRestore(context: ModelContext) throws {
        let current = try makeBackup(context: context, includePhotos: true)
        guard !current.entries.isEmpty else { return } // Nothing to lose, e.g. during setup.
        guard let folder = folderURL() else {
            throw hasFolder ? BackupError.folderUnavailable : BackupError.noFolderForSafetyCopy
        }
        guard folder.startAccessingSecurityScopedResource() else { throw BackupError.folderUnavailable }
        defer { folder.stopAccessingSecurityScopedResource() }
        let name = "\(beforeRestorePrefix) \(Int(Date.now.timeIntervalSince1970)).json"
        try encoder.encode(current).write(to: folder.appendingPathComponent(name), options: .atomic)
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
