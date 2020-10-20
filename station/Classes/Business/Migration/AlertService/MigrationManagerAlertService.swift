import Foundation
import RealmSwift
import AVKit

class MigrationManagerAlertService: MigrationManager {

    // persistence
    var alertService: AlertService!
    var alertPersistence: AlertPersistence!
    var realmContext: RealmContext!
    var ruuviTagTrunk: RuuviTagTrunk!
    var settings: Settings!
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
        var sensors: [(String, Temperature?)] = fetchWebTags()
        fetchRuuviSensors {
            sensors.append(contentsOf: $0)
            self.queue.async {
                let group = DispatchGroup()
                sensors.forEach({ element in
                    group.enter()
                    self.migrateTo1Version(element: element, completion: {
                        group.leave()
                    })
                })
                group.wait()
                group.notify(queue: .main, execute: {
                    completion(true)
                })
            }
        }
    }

    private func migrateTo1Version(element: (String, Temperature?), completion: @escaping (() -> Void)) {
        let id = element.0
        if prefs.bool(forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id),
           let lower = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityLowerBoundUDKeyPrefix + id),
           let upper = prefs.optionalDouble(forKey: Keys.Ver1.relativeHumidityUpperBoundUDKeyPrefix + id),
           let temperature = element.1 {
            prefs.set(false, forKey: Keys.Ver1.relativeHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity: Humidity = Humidity(value: lower / 100,
                                                   unit: .relative(temperature: temperature))
            let upperHumidity: Humidity = Humidity(value: upper / 100,
                                                   unit: .relative(temperature: temperature))
            alertService.register(type: .humidity(lower: lowerHumidity, upper: upperHumidity),
                                  for: id)
        } else if prefs.bool(forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id),
                  let lower = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityLowerBoundUDKeyPrefix + id),
                  let upper = prefs.optionalDouble(forKey: Keys.Ver1.absoluteHumidityUpperBoundUDKeyPrefix + id) {
            prefs.set(false, forKey: Keys.Ver1.absoluteHumidityAlertIsOnUDKeyPrefix + id)
            let lowerHumidity: Humidity = Humidity(value: lower,
                                                   unit: .absolute)
            let upperHumidity: Humidity = Humidity(value: upper,
                                                   unit: .absolute)
            alertService.register(type: .humidity(lower: lowerHumidity,
                                                  upper: upperHumidity),
                                  for: id)
        } else {
            debugPrint("do nothing")
        }
        
        // pick one description, relative preffered
        let humidityDescription = prefs.string(forKey: Keys.Ver1.relativeHumidityAlertDescriptionUDKeyPrefix + id)
            ?? prefs.string(forKey: Keys.Ver1.absoluteHumidityAlertDescriptionUDKeyPrefix + id) 
        alertService.setHumidity(description: humidityDescription, for: id)
        
        completion()
    }

    private func fetchWebTags() -> [(String, Temperature?)] {
        realmContext.main.objects(WebTagRealm.self).map({
            return ($0.uuid, $0.lastRecord?.temperature)
        })
    }

    private func fetchRuuviSensors(completion: @escaping ([(String, Temperature?)]) -> Void) {
        var result: [(String, Temperature?)] = .init()
        queue.async {
            let group = DispatchGroup()
            group.enter()
            self.ruuviTagTrunk.readAll().on(success: {sensors in
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

    private func fetchRecord(for sensor: RuuviTagSensor, complete: @escaping (((String, Temperature?)) -> Void)) {
        let id = sensor.luid?.value ?? sensor.id
        ruuviTagTrunk.readLast(sensor).on(success: { record in
            complete((id, record?.temperature))
        }, failure: { _ in
            complete((id, nil))
        })
    }

}
