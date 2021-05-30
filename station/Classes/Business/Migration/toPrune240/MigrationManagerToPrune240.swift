import Foundation
import RuuviLocal

final class MigrationManagerToPrune240: MigrationManager {
    var settings: RuuviLocalSettings!

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.dataPruningOffsetHours = 240
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToPrune240.migrated"
}
