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

        Task { [weak self] in
            guard let self else { return }
            let tuples = await fetchRuuviSensors()
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

    private func fetchRuuviSensors() async -> [(RuuviTagSensor, Temperature?)] {
        let sensors: [AnyRuuviTagSensor]
        do {
            sensors = try await ruuviStorage.readAll()
        } catch {
            return []
        }

        var result = [(RuuviTagSensor, Temperature?)]()
        for sensor in sensors {
            let record = try? await ruuviStorage.readLatest(sensor)
            result.append((sensor, record?.temperature))
        }
        return result
    }
}
