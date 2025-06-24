import UIKit
import RuuviOntology
import RuuviLocal
import RuuviLocalization
import Humidity
import RuuviService
import BTKit

// MARK: - RuuviTagCardSnapshot Data Builder - Core
struct RuuviTagCardSnapshotDataBuilder {

    // MARK: - Create Indicator Grid from Record and Sensor
    static func createIndicatorGrid(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        alertData: RuuviTagCardSnapshotAlertData
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {

        var indicators: [RuuviTagCardSnapshotIndicatorData] = []

        // Determine which indicators to show based on version
        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(from: sensor.version)
        if firmwareVersion == .e0 || firmwareVersion == .f0 {
            indicators = createIndicatorsForE0(
                record: record,
                sensor: sensor,
                measurementService: measurementService
            )
        } else {
            indicators = createIndicatorsForV5OrOlder(
                record: record,
                sensor: sensor,
                measurementService: measurementService
            )
        }

        guard !indicators.isEmpty else { return nil }
        return RuuviTagCardSnapshotIndicatorGridConfiguration(indicators: indicators)
    }

    // MARK: - V5 and Older Indicators
    private static func createIndicatorsForV5OrOlder(
        record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        var indicators: [RuuviTagCardSnapshotIndicatorData] = []

        // Temperature
        if let (value, unit) = getMeasurementValue(for: .temperature, from: record, measurementService: measurementService) {
            indicators.append(createIndicator(type: .temperature, value: value, unit: unit))
        }

        // Humidity
        if let (value, unit) = getMeasurementValue(for: .humidity, from: record, measurementService: measurementService) {
            indicators.append(createIndicator(type: .humidity, value: value, unit: unit))
        }

        // Pressure
        if let (value, unit) = getMeasurementValue(for: .pressure, from: record, measurementService: measurementService) {
            indicators.append(createIndicator(type: .pressure, value: value, unit: unit))
        }

        // Movement
        if let (value, unit) = getMeasurementValue(for: .movementCounter, from: record, measurementService: measurementService) {
            indicators.append(createIndicator(type: .movementCounter, value: value, unit: unit))
        }

        return indicators
    }

    // MARK: - E0 Indicators (Version 224/240)
    private static func createIndicatorsForE0(
        record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        var indicators: [RuuviTagCardSnapshotIndicatorData] = []

        let measurementTypes: [MeasurementType] = [
            .aqi, .temperature, .humidity, .pressure, .co2, .pm25, .pm10, .nox, .voc, .luminosity, .sound
        ]

        for type in measurementTypes {
            if let (value, unit) = getMeasurementValue(for: type, from: record, measurementService: measurementService) {
                indicators.append(createIndicator(type: type, value: value, unit: unit))
            }
        }

        return indicators
    }

    // MARK: - Create Indicator Helper
    private static func createIndicator(
        type: MeasurementType,
        value: String,
        unit: String
    ) -> RuuviTagCardSnapshotIndicatorData {
        return RuuviTagCardSnapshotIndicatorData(
            type: type,
            value: value,
            unit: unit,
            alertConfig: .inactive // Will be updated when alerts are synced
        )
    }

    // MARK: - Create Alert Config from Alert Service
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
            isFiring: false, // Will be updated by alert notifications
            mutedTill: mutedTill
        )
    }
}

// MARK: - Measurement Values Extraction
extension RuuviTagCardSnapshotDataBuilder {

    // MARK: - Get Measurement Values from Record
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func getMeasurementValue(
        for type: MeasurementType,
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?
    ) -> (value: String, unit: String)? {

        switch type {
        case .temperature:
            guard let temperature = record.temperature else { return nil }
            let value = measurementService?.stringWithoutSign(for: temperature) ??
                       String(format: "%.1f", temperature.value)
            let unit = measurementService?.units.temperatureUnit.symbol ?? RuuviLocalization.na
            return (value, unit)

        case .humidity:
            guard let humidity = record.humidity,
                  let measurementService = measurementService else { return nil }
            let value = measurementService.stringWithoutSign(
                for: humidity,
                temperature: record.temperature
            )
            let humidityUnit = measurementService.units.humidityUnit
            let unit = humidityUnit == .dew ?
                      measurementService.units.temperatureUnit.symbol :
                      humidityUnit.symbol
            return (value, unit)

        case .pressure:
            guard let pressure = record.pressure else { return nil }
            let value = measurementService?.stringWithoutSign(for: pressure) ??
                       String(format: "%.0f", pressure.value)
            let unit = measurementService?.units.pressureUnit.symbol ?? RuuviLocalization.na
            return (value, unit)

        case .co2:
            guard let co2 = record.co2,
                  let co2Value = measurementService?.co2String(for: co2) else { return nil }
            return (co2Value, RuuviLocalization.unitCo2)

        case .pm25:
            guard let pm25 = record.pm2_5,
                  let pm25Value = measurementService?.pm25String(for: pm25) else { return nil }
            return (pm25Value, "\(RuuviLocalization.pm25) \(RuuviLocalization.unitPm25)")

        case .pm10:
            guard let pm10 = record.pm10,
                  let pm10Value = measurementService?.pm10String(for: pm10) else { return nil }
            return (pm10Value, "\(RuuviLocalization.pm10) \(RuuviLocalization.unitPm10)")

        case .nox:
            guard let nox = record.nox,
                  let noxValue = measurementService?.noxString(for: nox) else { return nil }
            return (noxValue, RuuviLocalization.unitNox)

        case .voc:
            guard let voc = record.voc,
                  let vocValue = measurementService?.vocString(for: voc) else { return nil }
            return (vocValue, RuuviLocalization.unitVoc)

        case .luminosity:
            guard let luminosity = record.luminance,
                  let luminosityValue = measurementService?.luminosityString(for: luminosity) else { return nil }
            return (luminosityValue, RuuviLocalization.unitLuminosity)

        case .sound:
            guard let sound = record.dbaAvg,
                  let soundValue = measurementService?.soundAvgString(for: sound) else { return nil }
            return (soundValue, RuuviLocalization.unitSound)

        case .movementCounter:
            guard let movement = record.movementCounter else { return nil }
            return ("\(movement)", RuuviLocalization.Cards.Movements.title)

        case .aqi:
            guard let (currentAirQIndex, maximumAirQIndex, _) = measurementService?.aqiString(
                for: record.co2,
                pm25: record.pm2_5,
                voc: record.voc,
                nox: record.nox
            ) else { return nil }
            return ("\(currentAirQIndex.stringValue)/\(maximumAirQIndex.stringValue)",
                   RuuviLocalization.airQuality)

        default:
            return nil
        }
    }

    // MARK: - Firmware Detection
    static func isAdvancedFirmware(_ version: Int?) -> Bool {
        let firmwareVersion = RuuviFirmwareVersion.firmwareVersion(
            from: version.bound
        )
        return firmwareVersion == .e0 || firmwareVersion == .f0
    }

    // MARK: - Get Measurement Types for Firmware Version
    static func getMeasurementTypes(for version: Int?) -> [MeasurementType] {
        if isAdvancedFirmware(version) {
            // E0/F0 sensors
            return [.aqi, .temperature, .humidity, .pressure, .co2, .pm25, .pm10, .nox, .voc, .luminosity, .sound]
        } else {
            // V5 and older sensors
            return [.temperature, .humidity, .pressure, .movementCounter]
        }
    }

    // MARK: - Create Indicator with Alert Config
    static func createIndicator(
        type: MeasurementType,
        value: String,
        unit: String,
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
            alertConfig: alertConfig
        )
    }

    // MARK: - Update Indicators with Alert Configs
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
                alertConfig: alertConfig
            )
        }
    }
}

// MARK: - Legacy Support for CardsViewModel Migration
extension RuuviTagCardSnapshotDataBuilder {

    // MARK: - Create Enhanced Snapshot from CardsViewModel
    static func createSnapshot(
        from cardsViewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?,
        alertService: RuuviServiceAlert?,
        connectionPersistence: RuuviLocalConnections?,
        localSyncState: RuuviLocalSyncState?,
        backgroundService: BTBackground?
    ) -> RuuviTagCardSnapshot? {
        guard let id = cardsViewModel.id else { return nil }

        let identifierData = RuuviTagCardSnapshotIdentityData(
            luid: cardsViewModel.luid?.any as? LocalIdentifier,
            mac: cardsViewModel.mac?.any as? MACIdentifier,
            serviceUUID: cardsViewModel.serviceUUID
        )

        // Enhanced display data
        var displayData = RuuviTagCardSnapshotDisplayData(
            name: cardsViewModel.name,
            version: cardsViewModel.version,
            background: cardsViewModel.background,
            source: cardsViewModel.source,
            batteryNeedsReplacement: cardsViewModel.batteryNeedsReplacement ?? false,
            indicatorGrid: createIndicatorGridFromViewModel(
                cardsViewModel: cardsViewModel,
                measurementService: measurementService
            ),
            hasNoData: cardsViewModel.date == nil
        )

        // Set network sync status for MAC-based sensors
        if let macId = identifierData.mac, !cardsViewModel.isCloud {
            displayData.networkSyncStatus = localSyncState?.getSyncStatusLatestRecord(for: macId) ?? .none
        }

        // Enhanced connection data
        var keepConnection: Bool = false
        if let luid = identifierData.luid {
            keepConnection = connectionPersistence?.keepConnection(to: luid) ?? false
        }
        let connectionData = RuuviTagCardSnapshotConnectionData(
            isConnected: cardsViewModel.isConnected,
            isConnectable: cardsViewModel.isConnectable,
            keepConnection: keepConnection
        )

        let metadata = RuuviTagCardSnapshotMetadata(
            isChartAvailable: cardsViewModel.isConnectable,
            isAlertAvailable: cardsViewModel.isAlertAvailable ?? false,
            isCloud: cardsViewModel.isCloud,
            isOwner: cardsViewModel.isOwner,
            canShareTag: cardsViewModel.canShareTag
        )

        // Enhanced alert data
        let alertData = createAlertDataFromViewModel(cardsViewModel)

        let snapshot = RuuviTagCardSnapshot(
            id: id,
            identifierData: identifierData,
            displayData: displayData,
            metadata: metadata,
            alertData: alertData,
            connectionData: connectionData,
            lastUpdated: cardsViewModel.date
        )

        snapshot.latestRawRecord = cardsViewModel.latestMeasurement

        return snapshot
    }

    // MARK: - Create Alert Data from CardsViewModel
    private static func createAlertDataFromViewModel(
        _ cardsViewModel: CardsViewModel
    ) -> RuuviTagCardSnapshotAlertData {

        let alertData = RuuviTagCardSnapshotAlertData(
            alertState: cardsViewModel.alertState,
            hasActiveAlerts: hasActiveAlerts(from: cardsViewModel)
        )

        return alertData
    }

    // MARK: - Helper Methods
    private static func hasActiveAlerts(from cardsViewModel: CardsViewModel) -> Bool {
        let alertStates = [
            cardsViewModel.temperatureAlertState,
            cardsViewModel.relativeHumidityAlertState,
            cardsViewModel.pressureAlertState,
            cardsViewModel.movementAlertState,
            cardsViewModel.carbonDioxideAlertState,
            cardsViewModel.pMatter2_5AlertState,
            cardsViewModel.pMatter10AlertState,
            cardsViewModel.vocAlertState,
            cardsViewModel.noxAlertState,
            cardsViewModel.soundAlertState,
            cardsViewModel.luminosityAlertState,
        ]

        return alertStates.contains { $0 == .firing }
    }
}

// MARK: - Indicator Grid Creation from CardsViewModel
extension RuuviTagCardSnapshotDataBuilder {

    // MARK: - Create Indicator Grid from CardsViewModel
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func createIndicatorGridFromViewModel(
        cardsViewModel: CardsViewModel,
        measurementService: RuuviServiceMeasurement?
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        var indicators: [RuuviTagCardSnapshotIndicatorData] = []

        // Air Quality Index (for advanced sensors)
        if let co2 = cardsViewModel.co2,
           let pm25 = cardsViewModel.pm2_5,
           let voc = cardsViewModel.voc,
           let nox = cardsViewModel.nox,
           let (currentAirQIndex, maximumAirQIndex, _) = measurementService?.aqiString(
               for: co2, pm25: pm25, voc: voc, nox: nox
           ) {
            let alertConfig = createAlertConfigFromViewModel(for: .aqi, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .aqi,
                value: "\(currentAirQIndex.stringValue)/\(maximumAirQIndex.stringValue)",
                unit: RuuviLocalization.airQuality,
                alertConfig: alertConfig
            ))
        }

        // Temperature
        if let temperature = cardsViewModel.temperature {
            let tempValue = measurementService?.stringWithoutSign(for: temperature) ??
                           String(format: "%.1f", temperature.value)
            let tempUnit = measurementService?.units.temperatureUnit.symbol ?? RuuviLocalization.na
            let alertConfig = createAlertConfigFromViewModel(for: .temperature, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .temperature,
                value: tempValue,
                unit: tempUnit,
                alertConfig: alertConfig
            ))
        }

        // Humidity
        if let humidity = cardsViewModel.humidity,
           let measurementService = measurementService {
            let humidityValue = measurementService.stringWithoutSign(
                for: humidity,
                temperature: cardsViewModel.temperature
            )
            let humidityUnit = measurementService.units.humidityUnit
            let humidityUnitSymbol = humidityUnit.symbol
            let temperatureUnitSymbol = measurementService.units.temperatureUnit.symbol
            let unit = humidityUnit == .dew ? temperatureUnitSymbol : humidityUnitSymbol
            let alertConfig = createAlertConfigFromViewModel(for: .humidity, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .humidity,
                value: humidityValue,
                unit: unit,
                alertConfig: alertConfig
            ))
        }

        // Pressure
        if let pressure = cardsViewModel.pressure {
            let pressureValue = measurementService?.stringWithoutSign(for: pressure) ??
                               String(format: "%.0f", pressure.value)
            let pressureUnit = measurementService?.units.pressureUnit.symbol ?? RuuviLocalization.na
            let alertConfig = createAlertConfigFromViewModel(for: .pressure, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .pressure,
                value: pressureValue,
                unit: pressureUnit,
                alertConfig: alertConfig
            ))
        }

        // CO2
        if let co2 = cardsViewModel.co2,
           let co2Value = measurementService?.co2String(for: co2) {
            let alertConfig = createAlertConfigFromViewModel(for: .co2, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .co2,
                value: co2Value,
                unit: RuuviLocalization.unitCo2,
                alertConfig: alertConfig
            ))
        }

        // PM2.5
        if let pm25 = cardsViewModel.pm2_5,
           let pm25Value = measurementService?.pm25String(for: pm25) {
            let alertConfig = createAlertConfigFromViewModel(for: .pm25, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .pm25,
                value: pm25Value,
                unit: "\(RuuviLocalization.pm25) \(RuuviLocalization.unitPm25)",
                alertConfig: alertConfig
            ))
        }

        // PM10
        if let pm10 = cardsViewModel.pm10,
           let pm10Value = measurementService?.pm10String(for: pm10) {
            let alertConfig = createAlertConfigFromViewModel(for: .pm10, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .pm10,
                value: pm10Value,
                unit: "\(RuuviLocalization.pm10) \(RuuviLocalization.unitPm10)",
                alertConfig: alertConfig
            ))
        }

        // VOC
        if let voc = cardsViewModel.voc,
           let vocValue = measurementService?.vocString(for: voc) {
            let alertConfig = createAlertConfigFromViewModel(for: .voc, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .voc,
                value: vocValue,
                unit: RuuviLocalization.unitVoc,
                alertConfig: alertConfig
            ))
        }

        // NOx
        if let nox = cardsViewModel.nox,
           let noxValue = measurementService?.noxString(for: nox) {
            let alertConfig = createAlertConfigFromViewModel(for: .nox, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .nox,
                value: noxValue,
                unit: RuuviLocalization.unitNox,
                alertConfig: alertConfig
            ))
        }

        // Luminosity
        if let luminance = cardsViewModel.luminance,
           let luminosityValue = measurementService?.luminosityString(for: luminance) {
            let alertConfig = createAlertConfigFromViewModel(for: .luminosity, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .luminosity,
                value: luminosityValue,
                unit: RuuviLocalization.unitLuminosity,
                alertConfig: alertConfig
            ))
        }

        // Sound
        if let dbaAvg = cardsViewModel.dbaAvg,
           let soundValue = measurementService?.soundAvgString(for: dbaAvg) {
            let alertConfig = createAlertConfigFromViewModel(for: .sound, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .sound,
                value: soundValue,
                unit: RuuviLocalization.unitSound,
                alertConfig: alertConfig
            ))
        }

        // Movement
        if let movementCounter = cardsViewModel.movementCounter {
            let alertConfig = createAlertConfigFromViewModel(for: .movementCounter, from: cardsViewModel)
            indicators.append(RuuviTagCardSnapshotIndicatorData(
                type: .movementCounter,
                value: "\(movementCounter)",
                unit: RuuviLocalization.Cards.Movements.title,
                alertConfig: alertConfig
            ))
        }

        guard !indicators.isEmpty else { return nil }
        return RuuviTagCardSnapshotIndicatorGridConfiguration(indicators: indicators)
    }
}

// MARK: - Alert Config Creation from CardsViewModel
extension RuuviTagCardSnapshotDataBuilder {

    // MARK: - Create Alert Config from CardsViewModel
    static func createAlertConfigFromViewModel(
        for type: MeasurementType,
        from cardsViewModel: CardsViewModel
    ) -> RuuviTagCardSnapshotAlertConfig {

        // Check if alerts are visible
        guard cardsViewModel.alertState != nil && cardsViewModel.alertState != .empty else {
            return .inactive
        }

        // Get alert info for this measurement type
        let alertInfo = getAlertInfo(for: type, from: cardsViewModel)

        guard alertInfo.isOn, let alertState = alertInfo.alertState else {
            return .inactive
        }

        return RuuviTagCardSnapshotAlertConfig(
            isActive: true,
            isFiring: alertState == .firing,
            mutedTill: alertInfo.mutedTill
        )
    }

    // MARK: - Get Alert Info Helper
    private static func getAlertInfo(
        for type: MeasurementType,
        from cardsViewModel: CardsViewModel
    ) -> (isOn: Bool, alertState: AlertState?, mutedTill: Date?) {

        switch type {
        case .temperature:
            return (
                cardsViewModel.isTemperatureAlertOn ?? false,
                cardsViewModel.temperatureAlertState,
                cardsViewModel.temperatureAlertMutedTill
            )

        case .humidity:
            return (
                cardsViewModel.isRelativeHumidityAlertOn ?? false,
                cardsViewModel.relativeHumidityAlertState,
                cardsViewModel.relativeHumidityAlertMutedTill
            )

        case .pressure:
            return (
                cardsViewModel.isPressureAlertOn ?? false,
                cardsViewModel.pressureAlertState,
                cardsViewModel.pressureAlertMutedTill
            )

        case .movementCounter:
            return (
                cardsViewModel.isMovementAlertOn ?? false,
                cardsViewModel.movementAlertState,
                cardsViewModel.movementAlertMutedTill
            )

        case .co2:
            return (
                cardsViewModel.isCarbonDioxideAlertOn ?? false,
                cardsViewModel.carbonDioxideAlertState,
                cardsViewModel.carbonDioxideAlertMutedTill
            )

        case .pm25:
            return (
                cardsViewModel.isPMatter2_5AlertOn ?? false,
                cardsViewModel.pMatter2_5AlertState,
                cardsViewModel.pMatter2_5AlertMutedTill
            )

        case .pm10:
            return (
                cardsViewModel.isPMatter10AlertOn ?? false,
                cardsViewModel.pMatter10AlertState,
                cardsViewModel.pMatter10AlertMutedTill
            )

        case .nox:
            return (
                cardsViewModel.isNOXAlertOn ?? false,
                cardsViewModel.noxAlertState,
                cardsViewModel.noxAlertMutedTill
            )

        case .voc:
            return (
                cardsViewModel.isVOCAlertOn ?? false,
                cardsViewModel.vocAlertState,
                cardsViewModel.vocAlertMutedTill
            )

        case .sound:
            return (
                cardsViewModel.isSoundAlertOn ?? false,
                cardsViewModel.soundAlertState,
                cardsViewModel.soundAlertMutedTill
            )

        case .luminosity:
            return (
                cardsViewModel.isLuminosityAlertOn ?? false,
                cardsViewModel.luminosityAlertState,
                cardsViewModel.luminosityAlertMutedTill
            )

        case .aqi:
            // AQI uses temperature alert as fallback
            return (
                cardsViewModel.isTemperatureAlertOn ?? false,
                cardsViewModel.temperatureAlertState,
                cardsViewModel.temperatureAlertMutedTill
            )

        default:
            return (false, nil, nil)
        }
    }
}

// MARK: - Utilities and Helper Methods
extension RuuviTagCardSnapshotDataBuilder {

    // MARK: - Validate Indicator Data
    static func validateIndicatorData(_ indicators: [RuuviTagCardSnapshotIndicatorData]) -> [RuuviTagCardSnapshotIndicatorData] {
        return indicators.filter { indicator in
            !indicator.value.isEmpty && !indicator.unit.isEmpty
        }
    }

    // MARK: - Sort Indicators by Priority
    static func sortIndicatorsByPriority(_ indicators: [RuuviTagCardSnapshotIndicatorData]) -> [RuuviTagCardSnapshotIndicatorData] {
        let priorityOrder: [MeasurementType] = [
            .aqi, .temperature, .humidity, .pressure, .co2, .pm25, .pm10,
            .voc, .nox, .luminosity, .sound, .movementCounter
        ]

        return indicators.sorted { first, second in
            let firstIndex = priorityOrder.firstIndex(of: first.type) ?? Int.max
            let secondIndex = priorityOrder.firstIndex(of: second.type) ?? Int.max
            return firstIndex < secondIndex
        }
    }

    // MARK: - Create Empty Snapshot
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

    // MARK: - Update Snapshot with Latest Data
    static func updateSnapshot(
        _ snapshot: RuuviTagCardSnapshot,
        with record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        sensorSettings: SensorSettings? = nil,
        alertService: RuuviServiceAlert? = nil
    ) {
        // Update the snapshot using its own method
        snapshot.updateFromRecord(
            record,
            sensor: sensor,
            measurementService: measurementService,
            sensorSettings: sensorSettings
        )

        // Sync alerts if alert service is available
        if let alertService = alertService {
            snapshot.syncAllAlerts(from: alertService, physicalSensor: sensor)
        }
    }

    // MARK: - Compare Snapshots for Changes
    static func hasSignificantChanges(
        old: RuuviTagCardSnapshot?,
        new: RuuviTagCardSnapshot
    ) -> Bool {
        guard let old = old else { return true }

        // Check for significant changes that would require UI update
        return old.displayData.name != new.displayData.name ||
               old.displayData.hasNoData != new.displayData.hasNoData ||
               old.displayData.batteryNeedsReplacement != new.displayData.batteryNeedsReplacement ||
               old.connectionData.isConnected != new.connectionData.isConnected ||
               old.alertData.alertState != new.alertData.alertState ||
               old.lastUpdated != new.lastUpdated ||
               indicatorGridChanged(old: old.displayData.indicatorGrid, new: new.displayData.indicatorGrid)
    }

    // MARK: - Check if Indicator Grid Changed
    private static func indicatorGridChanged(
        old: RuuviTagCardSnapshotIndicatorGridConfiguration?,
        new: RuuviTagCardSnapshotIndicatorGridConfiguration?
    ) -> Bool {
        guard let oldGrid = old, let newGrid = new else {
            return old != nil || new != nil
        }

        // Check if number of indicators changed
        if oldGrid.indicators.count != newGrid.indicators.count {
            return true
        }

        // Check if any indicator values or alert states changed
        for (oldIndicator, newIndicator) in zip(oldGrid.indicators, newGrid.indicators) {
            if oldIndicator.type != newIndicator.type ||
               oldIndicator.value != newIndicator.value ||
               oldIndicator.unit != newIndicator.unit ||
               oldIndicator.alertConfig != newIndicator.alertConfig {
                return true
            }
        }

        return false
    }

    // MARK: - Get All Measurement Types
    static func getAllMeasurementTypes() -> [MeasurementType] {
        return [
            .aqi, .temperature, .humidity, .pressure, .co2, .pm25, .pm10,
            .nox, .voc, .luminosity, .sound, .movementCounter
        ]
    }

    // MARK: - Filter Indicators by Firmware
    static func filterIndicatorsForFirmware(
        _ indicators: [RuuviTagCardSnapshotIndicatorData],
        version: Int?
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        let supportedTypes = getMeasurementTypes(for: version)
        return indicators.filter { supportedTypes.contains($0.type) }
    }

    // MARK: - Create Indicator Grid Configuration
    static func createIndicatorGridConfiguration(
        indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        guard !indicators.isEmpty else { return nil }

        let validIndicators = validateIndicatorData(indicators)
        let sortedIndicators = sortIndicatorsByPriority(validIndicators)

        return RuuviTagCardSnapshotIndicatorGridConfiguration(indicators: sortedIndicators)
    }

    // MARK: - Merge Indicator Grids
    static func mergeIndicatorGrids(
        primary: RuuviTagCardSnapshotIndicatorGridConfiguration?,
        secondary: RuuviTagCardSnapshotIndicatorGridConfiguration?
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {

        var allIndicators: [RuuviTagCardSnapshotIndicatorData] = []

        if let primary = primary {
            allIndicators.append(contentsOf: primary.indicators)
        }

        if let secondary = secondary {
            // Add secondary indicators that don't already exist
            for indicator in secondary.indicators {
                if !allIndicators.contains(where: { $0.type == indicator.type }) {
                    allIndicators.append(indicator)
                }
            }
        }

        return createIndicatorGridConfiguration(indicators: allIndicators)
    }

    // MARK: - Extract Alert States
    static func extractAlertStates(
        from indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> (hasActive: Bool, hasFiring: Bool) {
        let hasActive = indicators.contains { $0.alertConfig.isActive }
        let hasFiring = indicators.contains { $0.alertConfig.isFiring }
        return (hasActive, hasFiring)
    }
}
