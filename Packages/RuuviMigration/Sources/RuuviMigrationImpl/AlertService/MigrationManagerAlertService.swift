#if SWIFT_PACKAGE
    import RuuviMigration
#endif
import Foundation
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerAlertService: RuuviMigration {
    private let storage: RuuviStorage
    private let alerts: RuuviServiceAlert
    private let defaults: UserDefaults
    private let versionKey = "MigrationManagerAlertService.persistanceVersion"
    @MainActor private var isRunning = false

    init(ruuviStorage: RuuviStorage, ruuviAlertService: RuuviServiceAlert, defaults: UserDefaults = .standard) {
        storage = ruuviStorage
        alerts = ruuviAlertService
        self.defaults = defaults
    }

    private struct Conversion {
        let sensor: RuuviTagSensor
        let type: AlertType
        let legacyKey: String
    }

    @MainActor func migrate() async throws {
        guard defaults.integer(forKey: versionKey) < 1, !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        try Task.checkCancellation()
        let sensors = try await storage.readAll()
        var conversions: [Conversion] = []
        for sensor in sensors {
            try Task.checkCancellation()
            let id = sensor.id
            if defaults.bool(forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id),
                let lower = defaults.optionalDouble(forKey: Keys.Ver1.relativeHumidityLowerBoundUDKeyPrefix + id),
                let upper = defaults.optionalDouble(forKey: Keys.Ver1.relativeHumidityUpperBoundUDKeyPrefix + id)
            {
                guard let temperature = try await migrationTemperature(for: sensor, storage: storage) else {
                    throw HumidityMigrationError.missingTemperature(id)
                }
                conversions.append(
                    Conversion(
                        sensor: sensor,
                        type: .humidity(
                            lower: Humidity(value: lower / 100, unit: .relative(temperature: temperature)),
                            upper: Humidity(value: upper / 100, unit: .relative(temperature: temperature))),
                        legacyKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id))
            } else if defaults.bool(forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id),
                let lower = defaults.optionalDouble(forKey: Keys.Ver1.absoluteHumidityLowerBoundUDKeyPrefix + id),
                let upper = defaults.optionalDouble(forKey: Keys.Ver1.absoluteHumidityUpperBoundUDKeyPrefix + id)
            {
                conversions.append(
                    Conversion(
                        sensor: sensor,
                        type: .humidity(
                            lower: Humidity(value: lower, unit: .absolute),
                            upper: Humidity(value: upper, unit: .absolute)),
                        legacyKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id))
            }
        }
        try Task.checkCancellation()
        for conversion in conversions {
            alerts.register(type: conversion.type, ruuviTag: conversion.sensor)
            defaults.set(false, forKey: conversion.legacyKey)
        }
        for sensor in sensors {
            if let description = defaults.string(
                forKey: Keys.Ver1.relativeHumidityAlertDescriptionUDKeyPrefix + sensor.id)
                ?? defaults.string(forKey: Keys.Ver1.absoluteHumidityAlertDescriptionUDKeyPrefix + sensor.id)
            {
                alerts.setHumidity(description: description, for: sensor)
            }
        }
        defaults.set(1, forKey: versionKey)
    }

    private enum Keys {
        enum Ver1 {
            // relativeHumidity
            static let relativeHumidityLowerBoundUDKeyPrefix =
                "AlertPersistenceUserDefaults.relativeHumidityLowerBoundUDKeyPrefix."
            static let relativeHumidityUpperBoundUDKeyPrefix =
                "AlertPersistenceUserDefaults.relativeHumidityUpperBoundUDKeyPrefix."
            static let relativeHumidityAlertIsOnUDKeyPrefix =
                "AlertPersistenceUserDefaults.relativeHumidityAlertIsOnUDKeyPrefix."
            static let relativeHumidityAlertDescriptionUDKeyPrefix =
                "AlertPersistenceUserDefaults.relativeHumidityAlertDescriptionUDKeyPrefix."
            // absoluteHumidity
            static let absoluteHumidityLowerBoundUDKeyPrefix =
                "AlertPersistenceUserDefaults.absoluteHumidityLowerBoundUDKeyPrefix."
            static let absoluteHumidityUpperBoundUDKeyPrefix =
                "AlertPersistenceUserDefaults.absoluteHumidityUpperBoundUDKeyPrefix."
            static let absoluteHumidityAlertIsOnUDKeyPrefix =
                "AlertPersistenceUserDefaults.absoluteHumidityAlertIsOnUDKeyPrefix."
            static let absoluteHumidityAlertDescriptionUDKeyPrefix =
                "AlertPersistenceUserDefaults.absoluteHumidityAlertDescriptionUDKeyPrefix."
        }
    }
}
