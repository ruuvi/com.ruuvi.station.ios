#if SWIFT_PACKAGE
    import RuuviMigration
#endif
#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviLocal
    import RuuviPool
    import RuuviStorage
    import RuuviService
#endif
import Foundation
import RuuviContext

final class MigrationManagerIsExcludedFromBackup: RuuviMigration {
    private let sqliteContext: SQLiteContext

    init(sqliteContext: SQLiteContext) {
        self.sqliteContext = sqliteContext
    }

    @MainActor func migrate() async throws {
        try Task.checkCancellation()
        let databaseURL = NSURL(fileURLWithPath: sqliteContext.database.dbPath)
        let values = try databaseURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        guard values[.isExcludedFromBackupKey] as? Bool != true else { return }
        try databaseURL.setResourceValue(true, forKey: .isExcludedFromBackupKey)
    }
}
