#if SWIFT_PACKAGE
    import RuuviMigration
#endif
import Foundation
import RuuviOntology
import RuuviService
import RuuviStorage

enum HumidityMigrationError: Error {
    case missingTemperature(String)
}

final class MigrationManagerToRH: RuuviMigration {
    private let storage: RuuviStorage
    private let alerts: RuuviServiceAlert
    private let defaults: UserDefaults
    private let migratedKey = "MigrationManagerToRH.migrated"
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
        var converted: [(RuuviTagSensor, AlertType)] = []
        // Finish reads before modifying settings, so a transient read failure remains retryable.
        for sensor in sensors {
            try Task.checkCancellation()
            guard let lower = alerts.lowerHumidity(for: sensor), let upper = alerts.upperHumidity(for: sensor),
                alerts.isOn(type: .humidity(lower: lower, upper: upper), for: sensor)
            else { continue }
            guard let temperature = try await migrationTemperature(for: sensor, storage: storage) else {
                throw HumidityMigrationError.missingTemperature(sensor.id)
            }
            converted.append(
                (
                    sensor,
                    .relativeHumidity(
                        lower: lower.converted(to: .relative(temperature: temperature)).value,
                        upper: upper.converted(to: .relative(temperature: temperature)).value)
                ))
        }
        try Task.checkCancellation()
        for (sensor, type) in converted { alerts.register(type: type, ruuviTag: sensor) }
        for sensor in sensors {
            if let description = alerts.humidityDescription(for: sensor) {
                alerts.setRelativeHumidity(description: description, ruuviTag: sensor)
            }
        }
        defaults.set(true, forKey: migratedKey)
    }
}

/// Older installations may have history before the latest-record cache was introduced.
func migrationTemperature(for sensor: RuuviTagSensor, storage: RuuviStorage) async throws -> Temperature? {
    if let temperature = try await storage.readLatest(sensor)?.temperature { return temperature }
    return try await storage.readLast(sensor)?.temperature
}
