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

final class MigrationManagerToNetworkPull60: RuuviMigration {
    private var settings: RuuviLocalSettings
    private let defaults: UserDefaults

    init(settings: RuuviLocalSettings, defaults: UserDefaults = .standard) {
        self.settings = settings
        self.defaults = defaults
    }

    @MainActor func migrate() async throws {
        try Task.checkCancellation()
        guard !defaults.bool(forKey: migratedUdKey) else { return }
        settings.networkPullIntervalSeconds = 60
        defaults.set(true, forKey: migratedUdKey)
    }

    private let migratedUdKey = "MigrationManagerToNetworkPull60.migrated"
}
