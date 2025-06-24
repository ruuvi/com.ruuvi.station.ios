// swiftlint:disable file_length

import UIKit
import RuuviOntology
import RuuviLocal
import RuuviLocalization
import Humidity
import RuuviService
import BTKit

// MARK: - RuuviTagCardSnapshot Data Builder
struct RuuviTagCardSnapshotDataBuilder {

    // MARK: - Constants
    private static let temperatureFormat = "%.1f"
    private static let pressureFormat = "%.0f"

    // MARK: - Main Factory Method
    static func createIndicatorGrid(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        alertData: RuuviTagCardSnapshotAlertData
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        let indicators = createIndicators(
            from: record,
            sensor: sensor,
            measurementService: measurementService,
            flags: flags
        )

        guard !indicators.isEmpty else { return nil }
        return RuuviTagCardSnapshotIndicatorGridConfiguration(indicators: indicators)
    }

    // MARK: - Indicator Creation
    private static func createIndicators(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(from: sensor.version)
        let measurementTypes = getMeasurementTypes(for: firmwareVersion)

        return measurementTypes.compactMap { type in
            guard let (value, unit, isProminent, showSubscript, tintColor) = getMeasurementValue(
                for: type,
                from: record,
                measurementService: measurementService,
                flags: flags
            ) else { return nil }

            return createIndicator(
                type: type,
                value: value,
                unit: unit,
                isProminent: isProminent,
                showSubscript: showSubscript,
                tintColor: tintColor
            )
        }
    }

    private static func getMeasurementTypes(
        for firmwareVersion: RuuviFirmwareVersion
    ) -> [MeasurementType] {
        switch firmwareVersion {
        case .e0, .f0:
            return [
                .aqi,
                .temperature,
                .humidity,
                .pressure,
                .co2,
                .pm25,
                .pm10,
                .nox,
                .voc,
                .luminosity,
                .sound,
            ]
        default:
            return [
                .temperature,
                .humidity,
                .pressure,
                .movementCounter,
            ]
        }
    }

    // swiftlint:disable:next function_parameter_count
    private static func createIndicator(
        type: MeasurementType,
        value: String,
        unit: String,
        isProminent: Bool,
        showSubscript: Bool,
        tintColor: UIColor?
    ) -> RuuviTagCardSnapshotIndicatorData {
        return RuuviTagCardSnapshotIndicatorData(
            type: type,
            value: value,
            unit: unit,
            alertConfig: .inactive,
            isProminent: isProminent,
            showSubscript: showSubscript,
            tintColor: tintColor
        )
    }
}

// MARK: - Measurement Value Extraction
extension RuuviTagCardSnapshotDataBuilder {

    // swiftlint:disable:next cyclomatic_complexity
    static func getMeasurementValue(
        for type: MeasurementType,
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        switch type {
        case .temperature:
            return getTemperatureValue(
                from: record,
                measurementService: measurementService,
                flags: flags
            )
        case .humidity:
            return getHumidityValue(from: record, measurementService: measurementService)
        case .pressure:
            return getPressureValue(from: record, measurementService: measurementService)
        case .co2:
            return getCO2Value(from: record, measurementService: measurementService)
        case .pm25:
            return getPM25Value(from: record, measurementService: measurementService)
        case .pm10:
            return getPM10Value(from: record, measurementService: measurementService)
        case .nox:
            return getNOXValue(from: record, measurementService: measurementService)
        case .voc:
            return getVOCValue(from: record, measurementService: measurementService)
        case .luminosity:
            return getLuminosityValue(from: record, measurementService: measurementService)
        case .sound:
            return getSoundValue(from: record, measurementService: measurementService)
        case .movementCounter:
            return getMovementValue(from: record)
        case .aqi:
            return getAQIValue(from: record, measurementService: measurementService)
        default:
            return nil
        }
    }

    // MARK: - Individual Measurement Extractors
    private static func getTemperatureValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let temperature = record.temperature else { return nil }

        let value = measurementService?.stringWithoutSign(for: temperature)
                   ?? String(format: temperatureFormat, temperature.value)
        let unit = measurementService?.units.temperatureUnit.symbol
                  ?? RuuviLocalization.na
        let firmware = RuuviFirmwareVersion.firmwareVersion(
            from: record.version
        )
        let isProminent = firmware == .e0 || firmware == .f0

        return (value, unit, isProminent, flags.showRedesignedDashboardUI, nil)
    }

    private static func getHumidityValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let humidity = record.humidity,
              let measurementService = measurementService else { return nil }

        let value = measurementService.stringWithoutSign(
            for: humidity,
            temperature: record.temperature
        )
        let humidityUnit = measurementService.units.humidityUnit
        let unit = humidityUnit == .dew
                  ? measurementService.units.temperatureUnit.symbol
                  : humidityUnit.symbol

        return (value, unit, false, false, nil)
    }

    private static func getPressureValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let pressure = record.pressure else { return nil }

        let value = measurementService?.stringWithoutSign(for: pressure)
                   ?? String(format: pressureFormat, pressure.value)
        let unit = measurementService?.units.pressureUnit.symbol
                  ?? RuuviLocalization.na

        return (value, unit, false, false, nil)
    }

    private static func getCO2Value(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let co2 = record.co2,
              let co2Value = measurementService?.co2String(for: co2) else { return nil }
        return (co2Value, RuuviLocalization.unitCo2, false, false, nil)
    }

    private static func getPM25Value(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let pm25 = record.pm2_5,
              let pm25Value = measurementService?.pm25String(for: pm25) else { return nil }
        return (pm25Value, "\(RuuviLocalization.unitPm25)", false, false, nil)
    }

    private static func getPM10Value(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let pm10 = record.pm10,
              let pm10Value = measurementService?.pm10String(for: pm10) else { return nil }
        return (pm10Value, "\(RuuviLocalization.unitPm10)", false, false, nil)
    }

    private static func getNOXValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let nox = record.nox,
              let noxValue = measurementService?.noxString(for: nox) else { return nil }
        return (noxValue, RuuviLocalization.unitNox, false, false, nil)
    }

    private static func getVOCValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let voc = record.voc,
              let vocValue = measurementService?.vocString(for: voc) else { return nil }
        return (vocValue, RuuviLocalization.unitVoc, false, false, nil)
    }

    private static func getLuminosityValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let luminosity = record.luminance,
              let luminosityValue = measurementService?.luminosityString(for: luminosity) else { return nil }
        return (luminosityValue, RuuviLocalization.unitLuminosity, false, false, nil)
    }

    private static func getSoundValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let sound = record.dbaAvg,
              let soundValue = measurementService?.soundAvgString(for: sound) else { return nil }
        return (soundValue, RuuviLocalization.unitSound, false, false, nil)
    }

    private static func getMovementValue(
        from record: RuuviTagSensorRecord
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let movement = record.movementCounter else { return nil }
        return ("\(movement)", RuuviLocalization.Cards.Movements.title, false, false, nil)
    }

    private static func getAQIValue(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
        // swiftlint:disable:next large_tuple
    ) -> (value: String, unit: String, isProminent: Bool, showSubscript: Bool, tintColor: UIColor?)? {
        guard let (currentAirQIndex, maximumAirQIndex, state) = measurementService?.aqiString(
            for: record.co2,
            pm25: record.pm2_5,
            voc: record.voc,
            nox: record.nox
        ) else { return nil }

        return (
            "\(currentAirQIndex.stringValue)/\(maximumAirQIndex.stringValue)",
            RuuviLocalization.airQuality, true, true, state.color
        )
    }
}

// MARK: - Alert Configuration
extension RuuviTagCardSnapshotDataBuilder {

    static func createAlertConfig(
        for type: MeasurementType,
        alertService: RuuviServiceAlert,
        physicalSensor: PhysicalSensor
    ) -> RuuviTagCardSnapshotAlertConfig {
        let alertType = type.toAlertType()
        let isOn = alertService.isOn(type: alertType, for: physicalSensor)
        let mutedTill = alertService.mutedTill(type: alertType, for: physicalSensor)

        return RuuviTagCardSnapshotAlertConfig(
            isActive: isOn,
            isFiring: false,
            mutedTill: mutedTill
        )
    }

    static func createIndicator(
        type: MeasurementType,
        value: String,
        unit: String,
        isProminent: Bool,
        showSubscript: Bool,
        tintColor: UIColor?,
        alertService: RuuviServiceAlert?,
        physicalSensor: PhysicalSensor?
    ) -> RuuviTagCardSnapshotIndicatorData {
        let alertConfig: RuuviTagCardSnapshotAlertConfig

        if let alertService = alertService, let physicalSensor = physicalSensor {
            alertConfig = createAlertConfig(
                for: type,
                alertService: alertService,
                physicalSensor: physicalSensor
            )
        } else {
            alertConfig = .inactive
        }

        return RuuviTagCardSnapshotIndicatorData(
            type: type,
            value: value,
            unit: unit,
            alertConfig: alertConfig,
            isProminent: isProminent,
            showSubscript: showSubscript,
            tintColor: tintColor
        )
    }

    static func updateIndicatorsWithAlerts(
        indicators: [RuuviTagCardSnapshotIndicatorData],
        alertService: RuuviServiceAlert,
        physicalSensor: PhysicalSensor
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        return indicators.map { indicator in
            let alertConfig = createAlertConfig(
                for: indicator.type,
                alertService: alertService,
                physicalSensor: physicalSensor
            )

            return RuuviTagCardSnapshotIndicatorData(
                type: indicator.type,
                value: indicator.value,
                unit: indicator.unit,
                alertConfig: alertConfig,
                isProminent: indicator.isProminent,
                showSubscript: indicator.showSubscript,
                tintColor: indicator.tintColor
            )
        }
    }
}

// MARK: - Firmware Detection and Configuration
extension RuuviTagCardSnapshotDataBuilder {

    static func isAdvancedFirmware(_ version: Int?) -> Bool {
        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(from: version.bound)
        return firmwareVersion == .e0 || firmwareVersion == .f0
    }

    static func getMeasurementTypes(for version: Int?) -> [MeasurementType] {
        return getMeasurementTypes(for: RuuviFirmwareVersion.firmwareVersion(from: version.bound))
    }

    static func filterIndicatorsForFirmware(
        _ indicators: [RuuviTagCardSnapshotIndicatorData],
        version: Int?
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        let supportedTypes = getMeasurementTypes(for: version)
        return indicators.filter { supportedTypes.contains($0.type) }
    }
}

// MARK: - Snapshot Management
extension RuuviTagCardSnapshotDataBuilder {

    // swiftlint:disable:next function_parameter_count
    static func createEmptySnapshot(
        id: String,
        name: String,
        luid: LocalIdentifier?,
        mac: MACIdentifier?,
        isCloud: Bool,
        isOwner: Bool,
        isConnectable: Bool,
        version: Int?
    ) -> RuuviTagCardSnapshot {
        return RuuviTagCardSnapshot.create(
            id: id,
            name: name,
            luid: luid,
            mac: mac,
            isCloud: isCloud,
            isOwner: isOwner,
            isConnectable: isConnectable,
            version: version
        )
    }

    static func updateSnapshot(
        _ snapshot: RuuviTagCardSnapshot,
        with record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        sensorSettings: SensorSettings? = nil,
        alertService: RuuviServiceAlert? = nil
    ) {
        snapshot.updateFromRecord(
            record,
            sensor: sensor,
            measurementService: measurementService,
            flags: flags,
            sensorSettings: sensorSettings
        )

        if let alertService = alertService {
            snapshot.syncAllAlerts(from: alertService, physicalSensor: sensor)
        }
    }

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
            oldIndicator.unit != newIndicator.unit ||
            oldIndicator.alertConfig != newIndicator.alertConfig
        }
    }
}

// MARK: - Utility Methods
extension RuuviTagCardSnapshotDataBuilder {

    static func validateIndicatorData(
        _ indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        return indicators.filter { !$0.value.isEmpty && !$0.unit.isEmpty }
    }

    static func sortIndicatorsByPriority(
        _ indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        let priorityOrder: [MeasurementType] = [
            .aqi,
            .temperature,
            .humidity,
            .pressure,
            .co2,
            .pm25,
            .pm10,
            .voc,
            .nox,
            .luminosity,
            .sound,
            .movementCounter,
        ]

        return indicators.sorted { first, second in
            let firstIndex = priorityOrder.firstIndex(of: first.type) ?? Int.max
            let secondIndex = priorityOrder.firstIndex(of: second.type) ?? Int.max
            return firstIndex < secondIndex
        }
    }

    static func createIndicatorGridConfiguration(
        indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        guard !indicators.isEmpty else { return nil }

        let validIndicators = validateIndicatorData(indicators)
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
            for indicator in secondary.indicators {
                // swiftlint:disable:next for_where
                if !allIndicators.contains(where: { $0.type == indicator.type }) {
                    allIndicators.append(indicator)
                }
            }
        }

        return createIndicatorGridConfiguration(indicators: allIndicators)
    }

    static func extractAlertStates(
        from indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> (hasActive: Bool, hasFiring: Bool) {
        let hasActive = indicators.contains { $0.alertConfig.isActive }
        let hasFiring = indicators.contains { $0.alertConfig.isFiring }
        return (hasActive, hasFiring)
    }

    static func getAllMeasurementTypes() -> [MeasurementType] {
        return [
            .aqi,
            .temperature,
            .humidity,
            .pressure,
            .co2,
            .pm25,
            .pm10,
            .nox,
            .voc,
            .luminosity,
            .sound,
            .movementCounter,
        ]
    }
}

// swiftlint:enable file_length
