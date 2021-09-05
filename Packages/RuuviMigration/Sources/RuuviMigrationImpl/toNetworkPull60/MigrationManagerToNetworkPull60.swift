import Foundation
import RuuviLocal
import RuuviMigration

final class MigrationManagerToNetworkPull60: RuuviMigration {
    private var settings: RuuviLocalSettings

    init(settings: RuuviLocalSettings) {
        self.settings = settings
    }

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.networkPullIntervalSeconds = 60
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToNetworkPull60.migrated"
}
