#if SWIFT_PACKAGE
    import RuuviMigration
#endif
import Foundation
import RuuviService
import RuuviStorage

final class RuuviMigrationFixRHAlerts: RuuviMigration {
    private let storage: RuuviStorage
    private let alerts: RuuviServiceAlert
    private let defaults: UserDefaults
    private let migratedKey = "RuuviMigrationFixRHAlerts.migrated"
    @MainActor private var isRunning = false

    init(ruuviStorage: RuuviStorage, ruuviAlertService: RuuviServiceAlert, defaults: UserDefaults = .standard) {
        storage = ruuviStorage
        alerts = ruuviAlertService
        self.defaults = defaults
    }

    @MainActor func migrate() async throws {
        guard !defaults.bool(forKey: migratedKey), !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        try Task.checkCancellation()
        let sensors = try await storage.readAll()
        for sensor in sensors {
            try Task.checkCancellation()
            if let lower = alerts.lowerRelativeHumidity(for: sensor), lower > 1 {
                alerts.setLower(relativeHumidity: lower / 100, ruuviTag: sensor)
            }
            if let upper = alerts.upperRelativeHumidity(for: sensor), upper > 1 {
                alerts.setUpper(relativeHumidity: upper / 100, ruuviTag: sensor)
            }
        }
        defaults.set(true, forKey: migratedKey)
    }
}
