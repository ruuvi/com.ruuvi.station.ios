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

    @UserDefault("MigrationManagerAlertService.persistanceVersion", defaultValue: 0)
    private var persistanceVersion: UInt

    private let actualServiceVersion: UInt = 1

    private let queue: DispatchQueue = DispatchQueue(label: "MigrationManagerAlertService", qos: .utility)

    func migrateIfNeeded() {
        persistanceVersion = 0
        for version in persistanceVersion..<actualServiceVersion {
            let nextVerstion = version + 1
            migrate(to: nextVerstion) { (result) in
                if result {
                    self.persistanceVersion = nextVerstion
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
}

// MARK: - v1 migration
extension MigrationManagerAlertService {

    private func migrateTo1Version(completion: @escaping ((Bool) -> Void)) {
        var sensors: [(String, Temperature?)] = fetchWebTags()
        fetchRuuviSensors { [weak self] in
            sensors.append(contentsOf: $0)
            self?.queue.async {
                let group = DispatchGroup()
                sensors.forEach({ element in
                    group.enter()
                    self?.migrateTo1Version(element: element, completion: {
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
        defer {
            completion()
        }
        let id = element.0
        if alertService.isOn(type: .relativeHumidity(lower: .nan, upper: .nan), for: id),
           let lower = alertService.lowerRelativeHumidity(for: id),
           let upper = alertService.upperRelativeHumidity(for: id) {
            alertService.unregister(type: .relativeHumidity(lower: .nan, upper: .nan), for: id)
            
            alertService.register(type: .absoluteHumidity(lower: <#T##Double#>, upper: <#T##Double#>), for: <#T##String#>)
        } else if alertService.isOn(type: .absoluteHumidity(lower: .nan, upper: .nan), for: id) {

        }
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
            self.ruuviTagTrunk.readAll().on(success: {[weak self] sensors in
                sensors.forEach({ sensor in
                    self?.fetchRecord(for: sensor) {
                        result.append($0)
                        group.leave()
                    }
                })
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
        ruuviTagTrunk.readLast(sensor).on(success: { record in
            complete((sensor.id, record?.temperature))
        }, failure: { _ in
            complete((sensor.id, nil))
        })
    }

}
