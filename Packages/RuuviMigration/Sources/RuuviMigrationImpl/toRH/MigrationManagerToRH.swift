import Foundation
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerToRH: RuuviMigration {
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
        queue.async { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                var aggregated: [(RuuviTagSensor, Temperature?)] = []
                do {
                    let sensors = try await self.ruuviStorage.readAll()
                    // Parallel fetch of latest records
                    try await withThrowingTaskGroup(of: (RuuviTagSensor, Temperature?).self) { group in
                        for sensor in sensors {
                            group.addTask {
                                let record = try? await self.ruuviStorage.readLatest(sensor)
                                return (sensor, record?.temperature)
                            }
                        }
                        for try await tuple in group {
                            aggregated.append(tuple)
                        }
                    }
                } catch {
                    // Ignore failures; will return what we have (empty if fatal at start)
                }
                completion(aggregated)
            }
        }
    }

    private func fetchRecord(
        for sensor: RuuviTagSensor,
        complete: @escaping (((RuuviTagSensor, Temperature?)) -> Void)
    ) {
        Task { [weak self] in
            guard let self else { return }
            let record = try? await ruuviStorage.readLatest(sensor)
            complete((sensor, record?.temperature))
        }
    }
}
