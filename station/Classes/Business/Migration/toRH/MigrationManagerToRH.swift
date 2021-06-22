import Foundation
import RuuviStorage
import RuuviOntology
import RuuviService

final class MigrationManagerToRH: MigrationManager {
    var ruuviStorage: RuuviStorage!
    var ruuviAlertService: RuuviServiceAlert!

    private let queue: DispatchQueue = DispatchQueue(label: "MigrationManagerToRH", qos: .utility)
    private let migratedUdKey = "MigrationManagerToRH.migrated"

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }

        fetchRuuviSensors { tuples in
            self.queue.async {
                tuples.forEach({ tuple in
                    let sensor = tuple.0
                    let temperature = tuple.1
                    if let lower = self.ruuviAlertService.lowerHumidity(for: sensor),
                       let upper = self.ruuviAlertService.upperHumidity(for: sensor),
                       let temperature = temperature {
                        let humidityType: AlertType = .humidity(lower: lower, upper: upper)
                        if self.ruuviAlertService.isOn(type: humidityType, for: sensor) {
                            self.ruuviAlertService.register(
                                type: .relativeHumidity(
                                    lower: lower.converted(to: .relative(temperature: temperature)).value,
                                    upper: upper.converted(to: .relative(temperature: temperature)).value),
                                ruuviTag: sensor)
                        }
                    }
                    if let description = self.ruuviAlertService.humidityDescription(for: sensor) {
                        self.ruuviAlertService.setRelativeHumidity(description: description, ruuviTag: sensor)
                    }
                })
            }
        }

        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private func fetchRuuviSensors(completion: @escaping ([(RuuviTagSensor, Temperature?)]) -> Void) {
        queue.async {
            let group = DispatchGroup()
            group.enter()
            var result = [(RuuviTagSensor, Temperature?)]()
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
