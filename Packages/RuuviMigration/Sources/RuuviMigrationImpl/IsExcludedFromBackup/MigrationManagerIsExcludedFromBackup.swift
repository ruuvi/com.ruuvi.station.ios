import Foundation
import RuuviContext

final class MigrationManagerIsExcludedFromBackup: RuuviMigration {
    private let sqliteContext: SQLiteContext

    init(sqliteContext: SQLiteContext) {
        self.sqliteContext = sqliteContext
    }

    func migrateIfNeeded() {
        let databaseUrl = NSURL(fileURLWithPath: sqliteContext.database.dbPath)
        do {
            let resourceValues = try databaseUrl.resourceValues(forKeys: [.isExcludedFromBackupKey])
            guard resourceValues[.isExcludedFromBackupKey] == nil
                    || resourceValues[.isExcludedFromBackupKey] as? Bool == false else {
                return
            }
            try databaseUrl.setResourceValue(true, forKey: .isExcludedFromBackupKey)
        } catch let error as NSError {
            print("Error excluding \(databaseUrl.lastPathComponent ?? "") from backup \(error)")
        }
    }

    private let migratedUdKey = "MigrationManagerIsExcludedFromBackup.migrated"
}
