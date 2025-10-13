// swiftlint:disable file_length

import UIKit
import RuuviOntology
import RuuviLocal
import RuuviLocalization
import Humidity
import RuuviService
import BTKit

// MARK: - Measurement Configuration
struct MeasurementConfiguration {
    static let temperatureFormat = "%.1f"
    static let pressureFormat = "%.0f"

    static let measurementPriority: [MeasurementType] = [
        .aqi, .co2, .pm25, .voc, .nox,
        .temperature, .anyHumidity, .pressure,
        .luminosity, .movementCounter, .soundInstant,
    ]

    static let advancedFirmwareMeasurements: [MeasurementType] = [
        .aqi, .temperature, .anyHumidity, .pressure, .co2,
        .pm25, .nox, .voc, .luminosity, .soundInstant,
    ]

    static let basicFirmwareMeasurements: [MeasurementType] = [
        .temperature, .anyHumidity, .pressure, .movementCounter
    ]
}

// MARK: - Measurement Result
struct MeasurementResult {
    init(
        value: String,
        unit: String,
        isProminent: Bool,
        showSubscript: Bool,
        tintColor: UIColor? = nil,
        qualityState: MeasurementQualityState? = nil
    ) {
        self.value = value
        self.unit = unit
        self.isProminent = isProminent
        self.showSubscript = showSubscript
        self.tintColor = tintColor
        self.qualityState = qualityState
    }

    let value: String
    let unit: String
    let isProminent: Bool
    let showSubscript: Bool
    let tintColor: UIColor?
    let qualityState: MeasurementQualityState?

    func toIndicatorData(
        type: MeasurementType
    ) -> RuuviTagCardSnapshotIndicatorData {
        return RuuviTagCardSnapshotIndicatorData(
            type: type,
            value: value,
            unit: unit,
            isProminent: isProminent,
            showSubscript: showSubscript,
            tintColor: tintColor,
            qualityState: qualityState
        )
    }
}

// MARK: - Measurement Extractor Protocol
protocol MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult?
}

// MARK: - Concrete Measurement Extractors
struct TemperatureMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let temperature = record.temperature,
              let measurementService = measurementService else { return nil }

        let value = measurementService.stringWithoutSign(for: temperature)
        let unit = measurementService.units.temperatureUnit.symbol
        let firmware = RuuviDataFormat.dataFormat(from: record.version)
        let isProminent = firmware == .e1 || firmware == .v6

        return MeasurementResult(
            value: value,
            unit: unit,
            isProminent: isProminent,
            showSubscript: flags.showRedesignedDashboardUI,
            tintColor: nil
        )
    }
}

struct HumidityMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let humidity = record.humidity,
              let measurementService = measurementService else { return nil }

        let value = measurementService.stringWithoutSign(for: humidity, temperature: record.temperature)
        let humidityUnit = measurementService.units.humidityUnit
        let unitSymbol = humidityUnit == .dew
                  ? measurementService.units.temperatureUnit.symbol
                  : humidityUnit.symbol

        return MeasurementResult(
            value: value,
            unit: unitSymbol,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct PressureMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let pressure = record.pressure,
              let measurementService = measurementService else { return nil }

        let value = measurementService.stringWithoutSign(for: pressure)
        let unit = measurementService.units.pressureUnit.symbol

        return MeasurementResult(
            value: value,
            unit: unit,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct MovementMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let movement = record.movementCounter else { return nil }

        return MeasurementResult(
            value: "\(movement)",
            unit: RuuviLocalization.movements,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct AQIMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let (currentAirQIndex, maximumAirQIndex, state) = measurementService?.aqi(
            for: record.co2,
            pm25: record.pm25
        ) else { return nil }

        return MeasurementResult(
            value: "\(currentAirQIndex.stringValue)/\(maximumAirQIndex.stringValue)",
            unit: RuuviLocalization.airQuality,
            isProminent: true,
            showSubscript: true,
            tintColor: state.color,
            qualityState: state
        )
    }
}

// MARK: - Air Quality Measurement Extractors
struct CO2MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let co2 = record.co2,
              let (_, state) = measurementService?.co2(for: co2),
              let co2Value = measurementService?.co2String(for: co2) else {
            return nil
        }

        return MeasurementResult(
            value: co2Value,
            unit: RuuviLocalization.unitCo2,
            isProminent: false,
            showSubscript: false,
            tintColor: state.color,
            qualityState: state
        )
    }
}

struct PM25MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let pm25 = record.pm25,
              let (_, state) = measurementService?.pm25(for: pm25),
              let pm25Value = measurementService?.pm25String(for: pm25) else {
            return nil
        }

        return MeasurementResult(
            value: pm25Value,
            unit: RuuviLocalization.unitPm25,
            isProminent: false,
            showSubscript: false,
            tintColor: state.color,
            qualityState: state
        )
    }
}

struct PM10MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let pm10 = record.pm10,
              let pm10Value = measurementService?.pm10String(for: pm10) else { return nil }

        return MeasurementResult(
            value: pm10Value,
            unit: RuuviLocalization.unitPm10,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct NOXMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let nox = record.nox,
              let noxValue = measurementService?.noxString(for: nox) else { return nil }

        return MeasurementResult(
            value: noxValue,
            unit: RuuviLocalization.unitNox,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct VOCMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let voc = record.voc,
              let vocValue = measurementService?.vocString(for: voc) else { return nil }

        return MeasurementResult(
            value: vocValue,
            unit: RuuviLocalization.unitVoc,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct LuminosityMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let luminosity = record.luminance,
              let luminosityValue = measurementService?.luminosityString(for: luminosity) else { return nil }

        return MeasurementResult(
            value: luminosityValue,
            unit: RuuviLocalization.unitLuminosity,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct SoundMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> MeasurementResult? {
        guard let sound = record.dbaInstant,
              let soundValue = measurementService?.soundString(for: sound) else { return nil }

        return MeasurementResult(
            value: soundValue,
            unit: RuuviLocalization.unitSound,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

// MARK: - Measurement Extractor Factory
struct MeasurementExtractorFactory {
    private static let extractors: [MeasurementType: MeasurementExtractor] = [
        .temperature: TemperatureMeasurementExtractor(),
        .anyHumidity: HumidityMeasurementExtractor(),
        .pressure: PressureMeasurementExtractor(),
        .movementCounter: MovementMeasurementExtractor(),
        .aqi: AQIMeasurementExtractor(),
        .co2: CO2MeasurementExtractor(),
        .pm25: PM25MeasurementExtractor(),
        .pm100: PM10MeasurementExtractor(),
        .nox: NOXMeasurementExtractor(),
        .voc: VOCMeasurementExtractor(),
        .luminosity: LuminosityMeasurementExtractor(),
        .soundInstant: SoundMeasurementExtractor(),
    ]

    static func extractor(for type: MeasurementType) -> MeasurementExtractor? {
        return extractors[type]
    }
}

// MARK: - Firmware Version Manager
struct FirmwareVersionManager {
    static func getMeasurementTypes(for firmwareVersion: RuuviDataFormat) -> [MeasurementType] {
        switch firmwareVersion {
        case .e1, .v6:
            return MeasurementConfiguration.advancedFirmwareMeasurements
        default:
            return MeasurementConfiguration.basicFirmwareMeasurements
        }
    }

    static func getMeasurementTypes(for version: Int?) -> [MeasurementType] {
        let firmwareVersion = RuuviDataFormat.dataFormat(from: version.bound)
        return getMeasurementTypes(for: firmwareVersion)
    }

    static func isAdvancedFirmware(_ version: Int?) -> Bool {
        let firmwareVersion = RuuviDataFormat.dataFormat(from: version.bound)
        return firmwareVersion == .e1 || firmwareVersion == .v6
    }
}

// MARK: - Indicator Data Manager
struct IndicatorDataManager {
    static func validateIndicators(
        _ indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        return indicators.filter { !$0.value.isEmpty && !$0.unit.isEmpty }
    }

    static func sortIndicatorsByPriority(
      _ indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> [RuuviTagCardSnapshotIndicatorData] {
      indicators.sorted { first, second in
        let p = MeasurementConfiguration.measurementPriority
        let i0 = p.firstIndexMatchingCase(of: first.type) ?? .max
        let i1 = p.firstIndexMatchingCase(of: second.type) ?? .max
        return i0 < i1
      }
    }

    static func createGridConfiguration(
        indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        guard !indicators.isEmpty else { return nil }

        let validIndicators = validateIndicators(indicators)
        let sortedIndicators = sortIndicatorsByPriority(validIndicators)

        return RuuviTagCardSnapshotIndicatorGridConfiguration(indicators: sortedIndicators)
    }

    static func mergeIndicatorGrids(
        primary: RuuviTagCardSnapshotIndicatorGridConfiguration?,
        secondary: RuuviTagCardSnapshotIndicatorGridConfiguration?
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        var allIndicators: [RuuviTagCardSnapshotIndicatorData] = []

        if let primary = primary {
            allIndicators.append(contentsOf: primary.indicators)
        }

        if let secondary = secondary {
            for indicator in secondary.indicators where
                !allIndicators.contains(where: { $0.type.isSameCase(as: indicator.type) }) {
              allIndicators.append(indicator)
            }
        }

        return createGridConfiguration(indicators: allIndicators)
    }

    static func extractAlertStates(
        from snapshot: RuuviTagCardSnapshot
    ) -> (hasActive: Bool, hasFiring: Bool) {
        let activeAlerts = snapshot.getAllActiveAlerts()
        let firingAlerts = snapshot.getAllFiringAlerts()
        return (hasActive: !activeAlerts.isEmpty, hasFiring: !firingAlerts.isEmpty)
    }
}

// MARK: - Alert Configuration Manager
struct AlertConfigurationManager {
    static func createAlertConfig(
        for type: MeasurementType,
        alertService: RuuviServiceAlert,
        physicalSensor: PhysicalSensor
    ) -> RuuviTagCardSnapshotAlertConfig {
        let alertType = type.toAlertType()
        let isOn = alertService.isOn(type: alertType, for: physicalSensor)
        let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

        return RuuviTagCardSnapshotAlertConfig(
            type: type,
            alertType: alertType,
            isActive: isOn,
            isFiring: false,
            mutedTill: mutedTill
        )
    }

    static func updateSnapshotWithAlerts(
        snapshot: RuuviTagCardSnapshot,
        alertService: RuuviServiceAlert,
        physicalSensor: PhysicalSensor
    ) {
        // Update measurement-based alerts
        for measurementType in MeasurementType.all {
            let alertConfig = createAlertConfig(
                for: measurementType,
                alertService: alertService,
                physicalSensor: physicalSensor
            )
            snapshot.updateAlertConfig(for: measurementType, config: alertConfig)
        }

        // Update non-measurement alerts
        let nonMeasurementAlertTypes: [AlertType] = [
            .connection, .cloudConnection(unseenDuration: 0), .movement(last: 0)
        ]
        for alertType in nonMeasurementAlertTypes {
            let isOn = alertService.isOn(type: alertType, for: physicalSensor)
            let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

            let config = RuuviTagCardSnapshotAlertConfig(
                alertType: alertType,
                isActive: isOn,
                isFiring: false,
                mutedTill: mutedTill
            )

            snapshot.updateAlertConfig(for: alertType, config: config)
        }
    }

    // swiftlint:disable:next function_parameter_count
    static func createIndicatorWithAlert(
        type: MeasurementType,
        value: String,
        unit: String,
        isProminent: Bool,
        showSubscript: Bool,
        tintColor: UIColor?,
        aqiState: MeasurementQualityState? = nil,
        alertService: RuuviServiceAlert?,
        physicalSensor: PhysicalSensor?
    ) -> RuuviTagCardSnapshotIndicatorData {
        return RuuviTagCardSnapshotIndicatorData(
            type: type,
            value: value,
            unit: unit,
            isProminent: isProminent,
            showSubscript: showSubscript,
            tintColor: tintColor,
            qualityState: aqiState
        )
    }
}

// MARK: - Snapshot Change Detector
struct SnapshotChangeDetector {
    static func hasSignificantChanges(
        old: RuuviTagCardSnapshot?,
        new: RuuviTagCardSnapshot
    ) -> Bool {
        guard let old = old else { return true }

        return old.displayData.name != new.displayData.name ||
               old.displayData.hasNoData != new.displayData.hasNoData ||
               old.displayData.batteryNeedsReplacement != new.displayData.batteryNeedsReplacement ||
               old.connectionData.isConnected != new.connectionData.isConnected ||
               old.alertData.alertState != new.alertData.alertState ||
               old.lastUpdated != new.lastUpdated ||
               indicatorGridChanged(old: old.displayData.indicatorGrid, new: new.displayData.indicatorGrid)
    }

    private static func indicatorGridChanged(
        old: RuuviTagCardSnapshotIndicatorGridConfiguration?,
        new: RuuviTagCardSnapshotIndicatorGridConfiguration?
    ) -> Bool {
        guard let oldGrid = old, let newGrid = new else {
            return old != nil || new != nil
        }

        guard oldGrid.indicators.count == newGrid.indicators.count else { return true }

        return zip(oldGrid.indicators, newGrid.indicators).contains { oldIndicator, newIndicator in
            oldIndicator.type != newIndicator.type ||
            oldIndicator.value != newIndicator.value ||
            oldIndicator.unit != newIndicator.unit
        }
    }
}

// MARK: - Main RuuviTagCardSnapshot Data Builder
struct RuuviTagCardSnapshotDataBuilder {

    // MARK: - Main Factory Method
    static func createIndicatorGrid(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        snapshot: RuuviTagCardSnapshot
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        let indicators = createIndicators(
            from: record,
            sensor: sensor,
            measurementService: measurementService,
            flags: flags,
            snapshot: snapshot
        )

        return IndicatorDataManager.createGridConfiguration(indicators: indicators)
    }

    // MARK: - Indicator Creation
    private static func createIndicators(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        snapshot: RuuviTagCardSnapshot
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        let firmwareVersion = RuuviDataFormat.dataFormat(from: sensor.version)
        let measurementTypes = FirmwareVersionManager.getMeasurementTypes(for: firmwareVersion)

        return measurementTypes.compactMap { type in
            guard let extractor = MeasurementExtractorFactory.extractor(for: type),
                  let result = extractor.extract(
                    from: record,
                    measurementService: measurementService,
                    flags: flags
                  ) else {
                return nil
            }

            let resolvedType: MeasurementType
            switch type {
            case .humidity:
              let unit = measurementService?.units.humidityUnit ?? .percent
              resolvedType = .humidity(unit)
            default:
              resolvedType = type
            }

            return result.toIndicatorData(type: resolvedType)
        }
    }
}

// swiftlint:enable file_length
