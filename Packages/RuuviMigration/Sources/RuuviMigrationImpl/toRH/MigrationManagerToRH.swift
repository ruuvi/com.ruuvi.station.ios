import Foundation
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerToRH: RuuviMigration, @unchecked Sendable {
    private let ruuviStorage: RuuviStorage
    private let ruuviAlertService: RuuviServiceAlert

    init(
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviAlertService = ruuviAlertService
    }

    private let queue: DispatchQueue = .init(label: "MigrationManagerToRH", qos: .utility)
    private let migratedUdKey = "MigrationManagerToRH.migrated"

    func migrateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedUdKey) else { return }

        fetchRuuviSensors { tuples in
            self.queue.async {
                tuples.forEach { tuple in
                    let sensor = tuple.0
                    let temperature = tuple.1
                    if let lower = self.ruuviAlertService.lowerHumidity(for: sensor),
                       let upper = self.ruuviAlertService.upperHumidity(for: sensor),
                       let temperature {
                        let humidityType: AlertType = .humidity(lower: lower, upper: upper)
                        if self.ruuviAlertService.isOn(type: humidityType, for: sensor) {
                            self.ruuviAlertService.register(
                                type: .relativeHumidity(
                                    lower: lower.converted(to: .relative(temperature: temperature)).value,
                                    upper: upper.converted(to: .relative(temperature: temperature)).value
                                ),
                                ruuviTag: sensor
                            )
                        }
                    }
                    if let description = self.ruuviAlertService.humidityDescription(for: sensor) {
                        self.ruuviAlertService.setRelativeHumidity(description: description, ruuviTag: sensor)
                    }
                }
            }
        }

        UserDefaults.standard.set(true, forKey: migratedUdKey)
    }

    private func fetchRuuviSensors(completion: @escaping ([(RuuviTagSensor, Temperature?)]) -> Void) {
        queue.async {
            Task {
                let sensors = (try? await self.ruuviStorage.readAll()) ?? []
                let group = DispatchGroup()
                var result = [(RuuviTagSensor, Temperature?)]()

                sensors.forEach { sensor in
                    group.enter()
                    self.fetchRecord(for: sensor) {
                        result.append($0)
                        group.leave()
                    }
                }

                group.notify(queue: .main, execute: {
                    completion(result)
                })
            }
        }
    }

    private func fetchRecord(
        for sensor: RuuviTagSensor,
        complete: @escaping (((RuuviTagSensor, Temperature?)) -> Void)
    ) {
        Task {
            let record = try? await ruuviStorage.readLatest(sensor)
            complete((sensor, record?.temperature))
        }
    }
}
