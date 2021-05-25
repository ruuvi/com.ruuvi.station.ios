import Foundation

final class MigrationManagerToPrune240: MigrationManager {
    var settings: Settings!

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.dataPruningOffsetHours = 240
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToPrune240.migrated"
}
