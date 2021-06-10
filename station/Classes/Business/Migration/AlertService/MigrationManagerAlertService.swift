import Foundation
import RealmSwift
import AVKit
import RuuviOntology
import RuuviContext
import RuuviStorage
import RuuviLocal
import RuuviService

final class MigrationManagerAlertService: MigrationManager {
    var realmContext: RealmContext!
    var ruuviStorage: RuuviStorage!
    var settings: RuuviLocalSettings!
    var ruuviAlertService: RuuviServiceAlert!

    private let prefs = UserDefaults.standard

    @UserDefault("MigrationManagerAlertService.persistanceVersion", defaultValue: 0)
    private var persistanceVersion: UInt

    private let actualServiceVersion: UInt = 1

    private let queue: DispatchQueue = DispatchQueue(label: "MigrationManagerAlertService", qos: .utility)

    func migrateIfNeeded() {
        guard persistanceVersion < actualServiceVersion else { return }
        for version in persistanceVersion..<actualServiceVersion {
            let nextVersion = version + 1
            migrate(to: nextVersion) { (result) in
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
            assert(false, "⛔️ Need implement v\(version) migration before")
            completion(true)
        }
    }

    private enum Keys {
        struct Ver1 {
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
        let virtualSensors = fetchVirtualSensors()
        self.queue.async {
            virtualSensors.forEach { virtualSensor in
                group.enter()
                self.migrateTo1Version(element: virtualSensor, completion: {
                    group.leave()
                })
            }
        }
        fetchRuuviSensors { ruuviTagSensors in
            self.queue.async {
                ruuviTagSensors.forEach({ element in
                    group.enter()
                    self.migrateTo1Version(element: element, completion: {
                        group.leave()
                    })
                })
            }
        }
        self.queue.async {
            group.notify(queue: .main, execute: {
                completion(true)
            })
        }
    }

    private func migrateTo1Version(element: (PhysicalSensor, Temperature?), completion: @escaping (() -> Void)) {
        let id = element.0.id
        if prefs.bool(forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id),
           let lower = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityLowerBoundUDKeyPrefix + id),
           let upper = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityUpperBoundUDKeyPrefix + id),
           let temperature = element.1 {
            prefs.set(false, forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity: Humidity = Humidity(value: lower / 100,
                                                   unit: .relative(temperature: temperature))
            let upperHumidity: Humidity = Humidity(value: upper / 100,
                                                   unit: .relative(temperature: temperature))
            ruuviAlertService.register(type: .humidity(lower: lowerHumidity, upper: upperHumidity),
                                  for: id)
        } else if prefs.bool(forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id),
                  let lower = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityLowerBoundUDKeyPrefix + id),
                  let upper = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityUpperBoundUDKeyPrefix + id) {
            prefs.set(false, forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity: Humidity = Humidity(value: lower,
                                                   unit: .absolute)
            let upperHumidity: Humidity = Humidity(value: upper,
                                                   unit: .absolute)
            ruuviAlertService.register(type: .humidity(lower: lowerHumidity,
                                                  upper: upperHumidity),
                                  for: id)
        } else {
            debugPrint("do nothing")
        }

        // pick one description, relative preffered
        let humidityDescription = prefs.string(forKey: Keys.Ver1.relativeHumidityAlertDescriptionUDKeyPrefix + id)
            ?? prefs.string(forKey: Keys.Ver1.absoluteHumidityAlertDescriptionUDKeyPrefix + id)
        ruuviAlertService.setHumidity(description: humidityDescription, for: element.0)

        completion()
    }

    private func migrateTo1Version(element: (VirtualSensor, Temperature?), completion: @escaping (() -> Void)) {
        let id = element.0.id
        if prefs.bool(forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id),
           let lower = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityLowerBoundUDKeyPrefix + id),
           let upper = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityUpperBoundUDKeyPrefix + id),
           let temperature = element.1 {
            prefs.set(false, forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity: Humidity = Humidity(value: lower / 100,
                                                   unit: .relative(temperature: temperature))
            let upperHumidity: Humidity = Humidity(value: upper / 100,
                                                   unit: .relative(temperature: temperature))
            ruuviAlertService.register(type: .humidity(lower: lowerHumidity, upper: upperHumidity),
                                  for: id)
        } else if prefs.bool(forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id),
                  let lower = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityLowerBoundUDKeyPrefix + id),
                  let upper = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityUpperBoundUDKeyPrefix + id) {
            prefs.set(false, forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity: Humidity = Humidity(value: lower,
                                                   unit: .absolute)
            let upperHumidity: Humidity = Humidity(value: upper,
                                                   unit: .absolute)
            ruuviAlertService.register(type: .humidity(lower: lowerHumidity,
                                                  upper: upperHumidity),
                                  for: id)
        } else {
            debugPrint("do nothing")
        }

        // pick one description, relative preffered
        let humidityDescription = prefs.string(forKey: Keys.Ver1.relativeHumidityAlertDescriptionUDKeyPrefix + id)
            ?? prefs.string(forKey: Keys.Ver1.absoluteHumidityAlertDescriptionUDKeyPrefix + id)
        ruuviAlertService.setHumidity(description: humidityDescription, for: element.0)

        completion()
    }

    private func fetchVirtualSensors() -> [(VirtualSensor, Temperature?)] {
        realmContext.main.objects(WebTagRealm.self).map({
            return ($0.struct, $0.lastRecord?.temperature)
        })
    }

    private func fetchRuuviSensors(completion: @escaping ([(RuuviTagSensor, Temperature?)]) -> Void) {
        var result: [(RuuviTagSensor, Temperature?)] = .init()
        queue.async {
            let group = DispatchGroup()
            group.enter()
            self.ruuviStorage.readAll().on(success: {sensors in
                sensors.forEach({ sensor in
                    group.enter()
                    self.fetchRecord(for: sensor) {
                        result.append($0)
                        group.leave()
                    }
                })
                group.leave()
            }, failure: { _ in
                group.leave()
            })
            group.wait()
            group.notify(queue: .main, execute: {
                completion(result)
            })
        }
    }

    private func fetchRecord(
        for sensor: RuuviTagSensor,
        complete: @escaping (((RuuviTagSensor, Temperature?)) -> Void)
    ) {
        ruuviStorage.readLast(sensor)
            .on(success: { record in
                complete((sensor, record?.temperature))
            }, failure: { _ in
                complete((sensor, nil))
            })
    }

}
