import Foundation
import RuuviLocal

final class MigrationManagerToChartDuration240: MigrationManager {
    var settings: RuuviLocalSettings!

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.chartDurationHours = 240
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToChartDuration240.migrated"
}
