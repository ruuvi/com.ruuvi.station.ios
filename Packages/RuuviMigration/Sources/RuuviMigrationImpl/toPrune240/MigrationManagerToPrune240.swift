import Foundation
import RuuviLocal
import RuuviMigration

final class MigrationManagerToPrune240: RuuviMigration {
    private var settings: RuuviLocalSettings

    init(settings: RuuviLocalSettings) {
        self.settings = settings
    }

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.dataPruningOffsetHours = 240
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToPrune240.migrated"
}
