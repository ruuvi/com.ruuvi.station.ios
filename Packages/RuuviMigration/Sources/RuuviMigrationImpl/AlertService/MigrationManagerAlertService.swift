import AVKit
import Foundation
import RuuviContext
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerAlertService: RuuviMigration, @unchecked Sendable {
    private let ruuviStorage: RuuviStorage
    private let ruuviAlertService: RuuviServiceAlert

    init(
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviAlertService = ruuviAlertService
    }

    private let prefs = UserDefaults.standard
    @UserDefault("MigrationManagerAlertService.persistanceVersion", defaultValue: 0)
    private var persistanceVersion: UInt
    private let actualServiceVersion: UInt = 1
    private let queue: DispatchQueue = .init(label: "MigrationManagerAlertService", qos: .utility)

    func migrateIfNeeded() {
        guard persistanceVersion < actualServiceVersion else { return }

        migrateTo1Version { result in
            if result {
                self.persistanceVersion = self.actualServiceVersion
            }
        }
    }

    private enum Keys {
        enum Ver1 {
            // relativeHumidity
            static let relativeHumidityLowerBoundUDKeyPrefix
                = "AlertPersistenceUserDefaults.relativeHumidityLowerBoundUDKeyPrefix."
            static let relativeHumidityUpperBoundUDKeyPrefix
                = "AlertPersistenceUserDefaults.relativeHumidityUpperBoundUDKeyPrefix."
            static let relativeHumidityAlertIsOnUDKeyPrefix
                = "AlertPersistenceUserDefaults.relativeHumidityAlertIsOnUDKeyPrefix."
            static let relativeHumidityAlertDescriptionUDKeyPrefix
                = "AlertPersistenceUserDefaults.relativeHumidityAlertDescriptionUDKeyPrefix."
            // absoluteHumidity
            static let absoluteHumidityLowerBoundUDKeyPrefix
                = "AlertPersistenceUserDefaults.absoluteHumidityLowerBoundUDKeyPrefix."
            static let absoluteHumidityUpperBoundUDKeyPrefix
                = "AlertPersistenceUserDefaults.absoluteHumidityUpperBoundUDKeyPrefix."
            static let absoluteHumidityAlertIsOnUDKeyPrefix
                = "AlertPersistenceUserDefaults.absoluteHumidityAlertIsOnUDKeyPrefix."
            static let absoluteHumidityAlertDescriptionUDKeyPrefix
                = "AlertPersistenceUserDefaults.absoluteHumidityAlertDescriptionUDKeyPrefix."
        }
    }
}

// MARK: - V1 migration

extension MigrationManagerAlertService {
    private func migrateTo1Version(completion: @escaping ((Bool) -> Void)) {
        fetchRuuviSensors { ruuviTagSensors in
            self.queue.async {
                ruuviTagSensors.forEach { element in
                    self.migrateTo1Version(element: element, completion: {})
                }
                DispatchQueue.main.async {
                    completion(true)
                }
            }
        }
    }

    private func migrateTo1Version(element: (RuuviTagSensor, Temperature?), completion: @escaping (() -> Void)) {
        let id = element.0.id
        if prefs.bool(forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id),
           let lower = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityLowerBoundUDKeyPrefix + id),
           let upper = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityUpperBoundUDKeyPrefix + id),
           let temperature = element.1 {
            prefs.set(false, forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity = Humidity(
                value: lower / 100,
                unit: .relative(temperature: temperature)
            )
            let upperHumidity = Humidity(
                value: upper / 100,
                unit: .relative(temperature: temperature)
            )
            ruuviAlertService.register(
                type: .humidity(lower: lowerHumidity, upper: upperHumidity),
                ruuviTag: element.0
            )
        } else if prefs.bool(forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id),
                  let lower = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityLowerBoundUDKeyPrefix + id),
                  let upper = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityUpperBoundUDKeyPrefix + id) {
            prefs.set(false, forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity = Humidity(
                value: lower,
                unit: .absolute
            )
            let upperHumidity = Humidity(
                value: upper,
                unit: .absolute
            )
            ruuviAlertService.register(
                type: .humidity(lower: lowerHumidity, upper: upperHumidity),
                ruuviTag: element.0
            )
        } else {
            debugPrint("do nothing")
        }

        // pick one description, relative preffered
        let humidityDescription = prefs.string(forKey: Keys.Ver1.relativeHumidityAlertDescriptionUDKeyPrefix + id)
            ?? prefs.string(forKey: Keys.Ver1.absoluteHumidityAlertDescriptionUDKeyPrefix + id)
        ruuviAlertService.setHumidity(description: humidityDescription, for: element.0)

        completion()
    }

    private func fetchRuuviSensors(completion: @escaping ([(RuuviTagSensor, Temperature?)]) -> Void) {
        queue.async {
            Task {
                let sensors = (try? await self.ruuviStorage.readAll()) ?? []
                var result = [(RuuviTagSensor, Temperature?)]()
                result.reserveCapacity(sensors.count)

                for sensor in sensors {
                    let record = try? await self.ruuviStorage.readLatest(sensor)
                    result.append((sensor, record?.temperature))
                }

                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
}
