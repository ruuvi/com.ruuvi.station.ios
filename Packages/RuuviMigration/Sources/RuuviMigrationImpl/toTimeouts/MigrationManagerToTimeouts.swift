#if SWIFT_PACKAGE
    import RuuviMigration
#endif
#if SWIFT_PACKAGE
    import RuuviOntology
    import RuuviPool
    import RuuviContext
    import RuuviStorage
    import RuuviService
#endif
import Foundation
import RuuviLocal

final class MigrationManagerToTimeouts: RuuviMigration {
    private var settings: RuuviLocalSettings

    init(settings: RuuviLocalSettings) {
        self.settings = settings
    }

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }
        settings.connectionTimeout = 30
        settings.serviceTimeout = 60
        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToTimeouts.migrated"
}
