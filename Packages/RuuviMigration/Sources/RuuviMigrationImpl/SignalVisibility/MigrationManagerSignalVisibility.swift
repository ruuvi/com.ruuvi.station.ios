#if SWIFT_PACKAGE
    import RuuviMigration
#endif
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviService
import RuuviStorage

final class MigrationManagerSignalVisibility: RuuviMigration {
    private let storage: RuuviStorage
    private let alerts: RuuviServiceAlert
    private let properties: RuuviServiceSensorProperties
    private var settings: RuuviLocalSettings
    private let defaults: UserDefaults
    private let migratedKey = "MigrationManagerSignalVisibility.didMigrate"
    @MainActor private var isRunning = false

    init(
        ruuviStorage: RuuviStorage, ruuviAlertService: RuuviServiceAlert,
        ruuviSensorProperties: RuuviServiceSensorProperties, ruuviLocalSettings: RuuviLocalSettings,
        defaults: UserDefaults = .standard
    ) {
        storage = ruuviStorage
        alerts = ruuviAlertService
        properties = ruuviSensorProperties
        settings = ruuviLocalSettings
        self.defaults = defaults
    }

    @MainActor func migrate() async throws {
        guard !defaults.bool(forKey: migratedKey) else {
            settings.signalVisibilityMigrationInProgress = false
            return
        }
        guard !isRunning else { return }
        isRunning = true
        settings.signalVisibilityMigrationInProgress = true
        defer {
            isRunning = false
            settings.signalVisibilityMigrationInProgress = false
        }
        try Task.checkCancellation()
        let sensors = try await storage.readAll()
        guard !sensors.isEmpty else { return }
        for sensor in sensors where sensor.isOwner {
            try Task.checkCancellation()
            guard alerts.isOn(type: .signal(lower: 0, upper: 0), for: sensor) else { continue }
            let stored = try await storage.readSensorSettings(sensor)
            var order = stored?.displayOrder ?? []
            guard !order.contains(MeasurementDisplayCode.signal) else { continue }
            if order.isEmpty { order = Self.defaultVisibleCodes(for: sensor) }
            guard !order.isEmpty else { continue }
            order.append(MeasurementDisplayCode.signal)
            _ = try await properties.updateDisplaySettings(for: sensor, displayOrder: order, defaultDisplayOrder: false)
        }
        defaults.set(true, forKey: migratedKey)
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
