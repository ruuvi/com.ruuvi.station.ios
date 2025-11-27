import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviService
import RuuviStorage

final class MigrationManagerSignalVisibility: RuuviMigration {
    private let ruuviStorage: RuuviStorage
    private let ruuviAlertService: RuuviServiceAlert
    private let ruuviSensorProperties: RuuviServiceSensorProperties
    private var ruuviLocalSettings: RuuviLocalSettings

    init(
        ruuviStorage: RuuviStorage,
        ruuviAlertService: RuuviServiceAlert,
        ruuviSensorProperties: RuuviServiceSensorProperties,
        ruuviLocalSettings: RuuviLocalSettings
    ) {
        self.ruuviStorage = ruuviStorage
        self.ruuviAlertService = ruuviAlertService
        self.ruuviSensorProperties = ruuviSensorProperties
        self.ruuviLocalSettings = ruuviLocalSettings
    }

    @UserDefault("MigrationManagerSignalVisibility.didMigrate", defaultValue: false)
    private var didMigrateSignalVisibility: Bool

    func migrateIfNeeded() {
        if didMigrateSignalVisibility {
            ruuviLocalSettings.signalVisibilityMigrationInProgress = false
            return
        }
        guard !ruuviLocalSettings.signalVisibilityMigrationInProgress else { return }

        ruuviLocalSettings.signalVisibilityMigrationInProgress = true

        ruuviStorage.readAll().on(success: { sensors in
            guard !sensors.isEmpty else {
                self.ruuviLocalSettings.signalVisibilityMigrationInProgress = false
                return
            }

            let group = DispatchGroup()
            sensors.forEach { sensor in
                group.enter()
                self.process(sensor: sensor) {
                    group.leave()
                }
            }

            group.notify(queue: .global(qos: .utility)) {
                self.didMigrateSignalVisibility = true
                self.ruuviLocalSettings.signalVisibilityMigrationInProgress = false
            }
        }, failure: { _ in
            self.ruuviLocalSettings.signalVisibilityMigrationInProgress = false
        })
    }
}

private extension MigrationManagerSignalVisibility {
    func process(sensor: AnyRuuviTagSensor, completion: @escaping () -> Void) {
        guard sensor.isOwner else { completion(); return }
        let signalAlertProbe = AlertType.signal(lower: 0, upper: 0)
        guard ruuviAlertService.isOn(type: signalAlertProbe, for: sensor) else {
            completion()
            return
        }

        ruuviStorage.readSensorSettings(sensor).on(success: { settings in
            self.ensureSignalMeasurementVisible(
                sensor: sensor,
                settings: settings,
                completion: completion
            )
        }, failure: { _ in
            self.ensureSignalMeasurementVisible(
                sensor: sensor,
                settings: nil,
                completion: completion
            )
        })
    }

    func ensureSignalMeasurementVisible(
        sensor: AnyRuuviTagSensor,
        settings: SensorSettings?,
        completion: @escaping () -> Void
    ) {
        let signalCode = MeasurementDisplayCode.signal
        var displayOrder = settings?.displayOrder ?? []

        if displayOrder.contains(signalCode) {
            completion()
            return
        }

        if displayOrder.isEmpty {
            let defaults = Self.defaultVisibleCodes(for: sensor)
            guard !defaults.isEmpty else {
                completion()
                return
            }
            displayOrder = defaults
        }

        guard !displayOrder.contains(signalCode) else {
            completion()
            return
        }
        displayOrder.append(signalCode)

        ruuviSensorProperties
            .updateDisplaySettings(
                for: sensor,
                displayOrder: displayOrder,
                defaultDisplayOrder: false
            )
            .on(success: { _ in
                completion()
            }, failure: { _ in
                completion()
            })
    }
}

private extension MigrationManagerSignalVisibility {
    static func defaultVisibleCodes(for sensor: RuuviTagSensor) -> [String] {
        let format = RuuviDataFormat.dataFormat(from: sensor.version)
        let measurementOrder = MeasurementDisplayDefaults.measurementOrder(for: format)
        return measurementOrder.flatMap { defaultCodes(for: $0) }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func defaultCodes(for type: MeasurementType) -> [String] {
        switch type {
        case .aqi:
            return [MeasurementDisplayCode.aqi]
        case .co2:
            return [MeasurementDisplayCode.co2]
        case .pm10, .pm40, .pm100:
            return []
        case .pm25:
            return [MeasurementDisplayCode.pm25]
        case .voc:
            return [MeasurementDisplayCode.voc]
        case .nox:
            return [MeasurementDisplayCode.nox]
        case .temperature:
            return [MeasurementDisplayCode.temperatureCelsius]
        case .humidity:
            return [MeasurementDisplayCode.humidityPercent]
        case .pressure:
            return [MeasurementDisplayCode.pressureHectopascals]
        case .luminosity:
            return [MeasurementDisplayCode.luminosity]
        case .movementCounter:
            return [MeasurementDisplayCode.movementCounter]
        case .soundInstant:
            return [MeasurementDisplayCode.soundInstant]
        case .soundAverage, .soundPeak:
            return []
        case .measurementSequenceNumber:
            return []
        case .voltage:
            return []
        case .accelerationX, .accelerationY, .accelerationZ:
            return []
        case .rssi:
            return []
        case .txPower:
            return []
        }
    }
}

private enum MeasurementDisplayCode {
    static let temperatureCelsius = "TEMPERATURE_C"
    static let humidityPercent = "HUMIDITY_0"
    static let pressureHectopascals = "PRESSURE_1"
    static let movementCounter = "MOVEMENT_COUNT"
    static let aqi = "AQI_INDEX"
    static let co2 = "CO2_PPM"
    static let pm25 = "PM25_MGM3"
    static let voc = "VOC_INDEX"
    static let nox = "NOX_INDEX"
    static let luminosity = "LUMINOSITY_LX"
    static let soundInstant = "SOUNDINSTANT_SPL"
    static let signal = "SIGNAL_DBM"
}
