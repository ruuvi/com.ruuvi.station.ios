import AVKit
import Foundation
import RuuviContext
import RuuviMigration
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerAlertService: RuuviMigration {
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
        for version in persistanceVersion ..< actualServiceVersion {
            let nextVersion = version + 1
            migrate(to: nextVersion) { result in
                if result {
                    self.persistanceVersion = nextVersion
                }
            }
        }
    }

    private func migrate(to version: UInt, completion: @escaping ((Bool) -> Void)) {
        switch version {
        case 1:
            migrateTo1Version(completion: completion)
        default:
            assertionFailure("⛔️ Need implement v\(version) migration before")
            completion(true)
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
        let group = DispatchGroup()
        group.enter()
        fetchRuuviSensors { ruuviTagSensors in
            self.queue.async {
                ruuviTagSensors.forEach { element in
                    group.enter()
                    self.migrateTo1Version(element: element, completion: {
                        group.leave()
                    })
                }
                group.leave()
            }
        }
        queue.async {
            group.notify(queue: .main, execute: {
                completion(true)
            })
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
            let group = DispatchGroup()
            group.enter()
            var result = [(RuuviTagSensor, Temperature?)]()
            self.ruuviStorage.readAll().on(success: { sensors in
                sensors.forEach { sensor in
                    group.enter()
                    self.fetchRecord(for: sensor) {
                        result.append($0)
                        group.leave()
                    }
                }
                group.leave()
            }, failure: { _ in
                group.leave()
            })
            group.notify(queue: .main, execute: {
                completion(result)
            })
        }
    }

    private func fetchRecord(
        for sensor: RuuviTagSensor,
        complete: @escaping (((RuuviTagSensor, Temperature?)) -> Void)
    ) {
        ruuviStorage.readLatest(sensor)
            .on(success: { record in
                complete((sensor, record?.temperature))
            }, failure: { _ in
                complete((sensor, nil))
            })
    }
}
