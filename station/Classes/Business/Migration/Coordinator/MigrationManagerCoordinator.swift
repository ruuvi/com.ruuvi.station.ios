import Foundation

class MigrationManagerCoordinator: MigrationManager {
    var toVIPER: MigrationManagerToVIPER!
    var toSQLite: MigrationManagerToSQLite!

    func migrateIfNeeded() {
        toVIPER.migrateIfNeeded()
        toSQLite.migrateIfNeeded()
    }
}
