import Foundation
import RuuviLocal

final class MigrationManagerToChartDuration240: RuuviMigration {
    private var settings: RuuviLocalSettings

    init(settings: RuuviLocalSettings) {
        self.settings = settings
    }

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.chartDurationHours = 240
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToChartDuration240.migrated"
}
