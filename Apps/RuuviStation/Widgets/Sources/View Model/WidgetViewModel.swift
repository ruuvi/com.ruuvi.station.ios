// swiftlint:disable file_length

import Foundation
import RuuviCloud
import RuuviLocalization
import RuuviOntology
import RuuviUser
import SwiftUI

struct WidgetMeasurementOption {
    let code: RuuviCloudSensorVisibilityCode
    let title: String
}

struct WidgetIndicatorDisplayItem: Identifiable, Hashable {
    let id: String
    let variant: MeasurementDisplayVariant
    let value: String
    let unit: String
    let title: String

    var hidesUnit: Bool {
        WidgetViewModel.isUnitHidden(for: variant.type)
    }
}

public final class WidgetViewModel: ObservableObject {
    private let widgetAssembly = WidgetAssembly.shared.assembler.resolver
    private let appGroupDefaults = UserDefaults(suiteName: Constants.appGroupBundleId.rawValue)
    private let userDefaultsQueue = DispatchQueue(label: Constants.queue.rawValue)

    private var ruuviCloud: RuuviCloud!
    private var ruuviUser: RuuviUser!

    private enum VisibilityDefaults {
        static let hiddenTypes: Set<MeasurementType> = [
            .pm10,
            .pm40,
            .pm100,
            .measurementSequenceNumber,
            .soundAverage,
            .soundPeak,
            .voltage,
            .rssi,
            .accelerationX,
            .accelerationY,
            .accelerationZ,
        ]
    }

    init() {
        ruuviUser = widgetAssembly.resolve(RuuviUser.self)
        ruuviCloud = widgetAssembly.resolve(RuuviCloud.self)
    }
}

// MARK: - Network calls

public extension WidgetViewModel {
    func fetchRuuviTags(completion: @escaping ([RuuviCloudSensorDense]) -> Void) {
        guard isAuthorized(), hasCloudSensors()
        else {
            completion([])
            return
        }
        foceRefreshWidget(false)
        ruuviCloud.loadSensorsDense(
            for: nil,
            measurements: true,
            sharedToOthers: nil,
            sharedToMe: true,
            alerts: nil,
            settings: true
        ).on(success: { sensors in
            let sensorsWithRecord = sensors.filter { $0.record != nil }
            completion(sensorsWithRecord)
        })
    }

    internal func fetchRuuviTagsAsync() async -> [RuuviCloudSensorDense] {
        await withCheckedContinuation { continuation in
            fetchRuuviTags { sensors in
                continuation.resume(returning: sensors)
            }
        }
    }
}

// MARK: - Public methods

public extension WidgetViewModel {
    func isAuthorized() -> Bool {
        appGroupDefaults?.bool(forKey: Constants.isAuthorizedUDKey.rawValue) ?? false
    }

    func getValue(
        from record: RuuviTagSensorRecord?,
        settings: SensorSettings?,
        config: RuuviTagSelectionIntent
    ) -> String {
        guard let record else {
            return "69.50" // Default value to show on the preview
        }

        let appSettings = getAppSettings()
        guard let variant = selectedVariant(
            from: config,
            appSettings: appSettings
        ) else {
            return formattedValue(
                for: defaultVariant(appSettings: appSettings),
                from: record,
                sensorSettings: settings,
                appSettings: appSettings
            )
        }

        return formattedValue(
            for: variant,
            from: record,
            sensorSettings: settings,
            appSettings: appSettings
        )
    }

    func getSensor(from config: RuuviTagSelectionIntent) -> WidgetSensorEnum? {
        if let identifier = config.sensorSelection?.identifier,
           let rawValue = Int(identifier),
           let sensor = WidgetSensorEnum(rawValue: rawValue) {
            return sensor
        } else {
            return WidgetSensorEnum(rawValue: config.sensor.rawValue)
        }
    }

    func getUnit(from config: RuuviTagSelectionIntent) -> String {
        let appSettings = getAppSettings()
        guard let variant = selectedVariant(
            from: config,
            appSettings: appSettings
        ) else {
            return unit(
                for: defaultVariant(appSettings: appSettings),
                appSettings: appSettings
            )
        }
        return unit(
            for: variant,
            appSettings: appSettings
        )
    }

    func getUnit(for sensor: WidgetSensorEnum?) -> String {
        guard let sensor else {
            return "\u{00B0}C" // Default unit to show on the preview
        }
        let appSettings = getAppSettings()
        let variant = legacyVariant(
            from: sensor,
            appSettings: appSettings
        )
        return unit(
            for: variant,
            appSettings: appSettings
        )
    }

    internal func measurementOptions(for deviceType: RuuviDeviceType) -> [WidgetMeasurementOption] {
        let appSettings = getAppSettings()
        return availableVariants(for: deviceType)
            .compactMap { variant in
                guard let code = variant.cloudVisibilityCode else {
                    return nil
                }
                return WidgetMeasurementOption(
                    code: code,
                    title: displayNameWithUnit(
                        for: variant,
                        appSettings: appSettings
                    )
                )
            }
    }

    internal func deviceType(from record: RuuviTagSensorRecord?) -> RuuviDeviceType {
        guard let version = record?.version else {
            return .unknown
        }
        let format = RuuviDataFormat.dataFormat(from: version)
        return (format == .e1 || format == .v6) ? .ruuviAir : .ruuviTag
    }

    internal func indicators(
        from record: RuuviTagSensorRecord?,
        settings: SensorSettings?,
        cloudSettings: RuuviCloudSensorSettings?,
        deviceType: RuuviDeviceType,
        selectedCodes: [RuuviCloudSensorVisibilityCode]
    ) -> [WidgetIndicatorDisplayItem] {
        guard let record else {
            return []
        }

        let appSettings = getAppSettings()
        let availableVariants = availableVariants(for: deviceType)

        let selectedVariants = uniqueOrderedVariants(
            selectedCodes.map { code in
                normalizedVariant(
                    code.variant,
                    appSettings: appSettings
                )
            }
        )
        .filter { variant in
            availableVariants.contains(variant)
        }

        let visibleVariants: [MeasurementDisplayVariant]
        if !selectedVariants.isEmpty {
            visibleVariants = selectedVariants
        } else {
            visibleVariants = resolvedVisibleVariants(
                availableVariants: availableVariants,
                cloudSettings: cloudSettings,
                appSettings: appSettings
            )
        }

        return visibleVariants
            .filter { variant in
                hasValue(
                    for: variant,
                    record: record,
                    sensorSettings: settings,
                    appSettings: appSettings
                )
            }
            .map { variant in
                WidgetIndicatorDisplayItem(
                    id: variantIdentifier(variant),
                    variant: variant,
                    value: formattedValue(
                        for: variant,
                        from: record,
                        sensorSettings: settings,
                        appSettings: appSettings
                    ),
                    unit: unit(
                        for: variant,
                        appSettings: appSettings
                    ),
                    title: shortName(for: variant)
                )
            }
    }

    internal func largeWidgetIndicators(from entry: WidgetEntry) -> [WidgetIndicatorDisplayItem] {
        let deviceType = resolvedDeviceType(for: entry)
        let appSettings = getAppSettings()
        let selectedCodes: [RuuviCloudSensorVisibilityCode] = {
            guard let identifier = entry.config.sensorSelection?.identifier,
                  let code = RuuviCloudSensorVisibilityCode.parse(identifier) else {
                guard let variant = selectedVariant(
                    from: entry.config,
                    appSettings: appSettings
                ),
                let fallbackCode = variant.cloudVisibilityCode else {
                    return []
                }
                return [fallbackCode]
            }
            return [code]
        }()

        return indicators(
            from: entry.record,
            settings: entry.settings,
            cloudSettings: entry.cloudSettings,
            deviceType: deviceType,
            selectedCodes: selectedCodes
        )
    }

    internal func relativeMeasurementTime(from entry: WidgetEntry) -> String {
        guard let date = entry.record?.date else {
            return RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    func locale() -> Locale {
        getLanguage().locale
    }

    func refreshIntervalMins() -> Int {
        if let interval = appGroupDefaults?
            .integer(
                forKey: Constants.widgetRefreshIntervalKey.rawValue
            ), interval > 0 {
            return interval
        }
        return 60
    }

    func shouldForceRefresh() -> Bool {
        if let forceRefresh = appGroupDefaults?
            .bool(forKey: Constants.forceRefreshWidgetKey.rawValue) {
            return forceRefresh
        }
        return false
    }

    func foceRefreshWidget(_ refresh: Bool) {
        userDefaultsQueue.sync {
            appGroupDefaults?.set(
                refresh,
                forKey: Constants.forceRefreshWidgetKey.rawValue
            )
        }
    }

    func getAppSettings() -> MeasurementServiceSettings {
        let temperatureUnit = temperatureUnit(from: appGroupDefaults)
        let temperatureAccuracy = temperatureAccuracy(from: appGroupDefaults)
        let humidityUnit = humidityUnit(from: appGroupDefaults)
        let humidityAccuracy = humidityAccuracy(from: appGroupDefaults)
        let pressureUnit = pressureUnit(from: appGroupDefaults)
        let pressureAccuracy = pressureAccuracy(from: appGroupDefaults)
        return MeasurementServiceSettings(
            temperatureUnit: temperatureUnit,
            temperatureAccuracy: temperatureAccuracy,
            humidityUnit: humidityUnit,
            humidityAccuracy: humidityAccuracy,
            pressureUnit: pressureUnit,
            pressureAccuracy: pressureAccuracy,
            language: getLanguage()
        )
    }

    /// Returns value for inline widget
    internal func getInlineWidgetValue(from entry: WidgetEntry) -> String {
        let value = getValue(
            from: entry.record,
            settings: entry.settings,
            config: entry.config
        )

        let unit = getUnit(from: entry.config)
        if unit.isEmpty {
            return value
        }
        return value + " " + unit
    }

    // Returns SF Symbol based on sensor since we
    // can not use Image in inline widget
    internal func symbol(from entry: WidgetEntry) -> Image {
        let appSettings = getAppSettings()
        guard let variant = selectedVariant(
            from: entry.config,
            appSettings: appSettings
        ) else {
            return Image(systemName: "thermometer.medium.slash")
        }

        switch variant.type {
        case .temperature:
            return Image(systemName: "thermometer.medium")
        case .humidity:
            return Image(systemName: "drop.circle")
        case .pressure:
            return Image(systemName: "wind.circle")
        case .movementCounter:
            return Image(systemName: "repeat.circle")
        case .accelerationX,
             .accelerationY,
             .accelerationZ:
            return Image(systemName: "move.3d")
        case .voltage:
            return Image(systemName: "bolt.circle.fill")
        case .aqi:
            return Image(systemName: "aqi.medium")
        case .co2:
            return Image(systemName: "cloud")
        case .nox:
            return Image(systemName: "smoke")
        case .voc:
            return Image(systemName: "wind")
        case .pm10,
             .pm25,
             .pm40,
             .pm100:
            return Image(systemName: "circle.hexagongrid")
        case .luminosity:
            return Image(systemName: "sun.max")
        case .soundInstant,
             .soundAverage,
             .soundPeak:
            return Image(systemName: "waveform")
        case .rssi:
            return Image(systemName: "antenna.radiowaves.left.and.right")
        case .measurementSequenceNumber:
            return Image(systemName: "number")
        default:
            return Image(systemName: "thermometer.medium.slash")
        }
    }

    internal func measurementTime(from entry: WidgetEntry) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        let date = entry.record?.date ?? Date()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        }
        return formatter.string(from: date)
    }

    static func isUnitHidden(for type: MeasurementType) -> Bool {
        switch type {
        case .aqi, .voc, .nox, .movementCounter, .measurementSequenceNumber:
            return true
        default:
            return false
        }
    }
}

// MARK: - Private methods

extension WidgetViewModel {
    private func hasCloudSensors() -> Bool {
        appGroupDefaults?.bool(forKey: Constants.hasCloudSensorsKey.rawValue) ?? false
    }

    private func getLanguage() -> Language {
        let languageCode = Bundle.main.preferredLocalizations[0]
        guard
            let language = Language(rawValue: languageCode)
        else {
            return .english
        }
        return language
    }

    private func defaultVariant(appSettings: MeasurementServiceSettings) -> MeasurementDisplayVariant {
        MeasurementDisplayVariant(
            type: .temperature,
            temperatureUnit: appSettings.temperatureUnit.temperatureUnit
        )
    }

    private func selectedVariant(
        from config: RuuviTagSelectionIntent,
        appSettings: MeasurementServiceSettings
    ) -> MeasurementDisplayVariant? {
        if let identifier = config.sensorSelection?.identifier {
            if let code = RuuviCloudSensorVisibilityCode.parse(identifier) {
                return normalizedVariant(
                    code.variant,
                    appSettings: appSettings
                )
            }

            if let rawValue = Int(identifier),
               let sensor = WidgetSensorEnum(rawValue: rawValue) {
                return legacyVariant(
                    from: sensor,
                    appSettings: appSettings
                )
            }
        }

        if let sensor = WidgetSensorEnum(rawValue: config.sensor.rawValue) {
            return legacyVariant(
                from: sensor,
                appSettings: appSettings
            )
        }

        return nil
    }

    private func normalizedVariant(
        _ variant: MeasurementDisplayVariant,
        appSettings: MeasurementServiceSettings
    ) -> MeasurementDisplayVariant {
        switch variant.type {
        case .temperature:
            return MeasurementDisplayVariant(
                type: .temperature,
                temperatureUnit: variant.temperatureUnit ?? appSettings.temperatureUnit.temperatureUnit
            )
        case .humidity:
            let humidityUnit = variant.humidityUnit ?? appSettings.humidityUnit
            if humidityUnit == .dew {
                return MeasurementDisplayVariant(
                    type: .humidity,
                    temperatureUnit: variant.temperatureUnit ?? appSettings.temperatureUnit.temperatureUnit,
                    humidityUnit: .dew
                )
            }
            return MeasurementDisplayVariant(
                type: .humidity,
                humidityUnit: humidityUnit
            )
        case .pressure:
            return MeasurementDisplayVariant(
                type: .pressure,
                pressureUnit: variant.pressureUnit ?? appSettings.pressureUnit
            )
        default:
            return variant
        }
    }

    private func legacyVariant(
        from sensor: WidgetSensorEnum,
        appSettings: MeasurementServiceSettings
    ) -> MeasurementDisplayVariant {
        switch sensor {
        case .temperature:
            return MeasurementDisplayVariant(
                type: .temperature,
                temperatureUnit: appSettings.temperatureUnit.temperatureUnit
            )
        case .humidity:
            if appSettings.humidityUnit == .dew {
                return MeasurementDisplayVariant(
                    type: .humidity,
                    temperatureUnit: appSettings.temperatureUnit.temperatureUnit,
                    humidityUnit: .dew
                )
            }
            return MeasurementDisplayVariant(
                type: .humidity,
                humidityUnit: appSettings.humidityUnit
            )
        case .pressure:
            return MeasurementDisplayVariant(
                type: .pressure,
                pressureUnit: appSettings.pressureUnit
            )
        case .movement_counter:
            return MeasurementDisplayVariant(type: .movementCounter)
        case .battery_voltage:
            return MeasurementDisplayVariant(type: .voltage)
        case .acceleration_x:
            return MeasurementDisplayVariant(type: .accelerationX)
        case .acceleration_y:
            return MeasurementDisplayVariant(type: .accelerationY)
        case .acceleration_z:
            return MeasurementDisplayVariant(type: .accelerationZ)
        case .air_quality:
            return MeasurementDisplayVariant(type: .aqi)
        case .co2:
            return MeasurementDisplayVariant(type: .co2)
        case .nox:
            return MeasurementDisplayVariant(type: .nox)
        case .voc:
            return MeasurementDisplayVariant(type: .voc)
        case .pm10:
            return MeasurementDisplayVariant(type: .pm10)
        case .pm25:
            return MeasurementDisplayVariant(type: .pm25)
        case .pm40:
            return MeasurementDisplayVariant(type: .pm40)
        case .pm100:
            return MeasurementDisplayVariant(type: .pm100)
        case .luminance:
            return MeasurementDisplayVariant(type: .luminosity)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func formattedValue(
        for variant: MeasurementDisplayVariant,
        from record: RuuviTagSensorRecord,
        sensorSettings: SensorSettings?,
        appSettings: MeasurementServiceSettings
    ) -> String {
        let settings = measurementSettings(
            for: variant,
            appSettings: appSettings
        )
        let measurementService = MeasurementService(settings: settings)

        switch variant.type {
        case .temperature:
            let temperature = record.temperature?.plus(sensorSettings: sensorSettings)
            return measurementService.temperature(for: temperature)
        case .humidity:
            let temperature = record.temperature?.plus(sensorSettings: sensorSettings)
            let humidity = record.humidity?.plus(sensorSettings: sensorSettings)
            return measurementService.humidity(
                for: humidity,
                temperature: temperature,
                isDecimal: false
            )
        case .pressure:
            let pressure = record.pressure?.plus(sensorSettings: sensorSettings)
            return measurementService.pressure(for: pressure)
        case .movementCounter:
            return measurementService.movements(for: record.movementCounter)
        case .voltage:
            return measurementService.voltage(for: record.voltage)
        case .accelerationX:
            return measurementService.acceleration(for: record.acceleration?.x.value)
        case .accelerationY:
            return measurementService.acceleration(for: record.acceleration?.y.value)
        case .accelerationZ:
            return measurementService.acceleration(for: record.acceleration?.z.value)
        case .aqi:
            guard record.co2 != nil, record.pm25 != nil else {
                return "-"
            }
            return measurementService.aqi(for: record.co2, and: record.pm25)
        case .co2:
            return measurementService.string(for: record.co2)
        case .nox:
            return measurementService.string(for: record.nox)
        case .voc:
            return measurementService.string(for: record.voc)
        case .pm10:
            return measurementService.string(for: record.pm1)
        case .pm25:
            return measurementService.string(for: record.pm25)
        case .pm40:
            return measurementService.string(for: record.pm4)
        case .pm100:
            return measurementService.string(for: record.pm10)
        case .luminosity:
            return measurementService.string(for: record.luminance)
        case .soundInstant:
            return measurementService.string(for: record.dbaInstant)
        case .soundAverage:
            return measurementService.string(for: record.dbaAvg)
        case .soundPeak:
            return measurementService.string(for: record.dbaPeak)
        case .rssi:
            return record.rssi.map { "\($0)" } ?? "-"
        case .measurementSequenceNumber:
            return record.measurementSequenceNumber.map { "\($0)" } ?? "-"
        default:
            return "-"
        }
    }

    private func measurementSettings(
        for variant: MeasurementDisplayVariant,
        appSettings: MeasurementServiceSettings
    ) -> MeasurementServiceSettings {
        var temperatureUnit = appSettings.temperatureUnit
        let humidityUnit = variant.humidityUnit ?? appSettings.humidityUnit
        let pressureUnit = variant.pressureUnit ?? appSettings.pressureUnit

        if let explicitTemperatureUnit = variant.temperatureUnit {
            temperatureUnit = explicitTemperatureUnit.unitTemperature
        }

        return MeasurementServiceSettings(
            temperatureUnit: temperatureUnit,
            temperatureAccuracy: appSettings.temperatureAccuracy,
            humidityUnit: humidityUnit,
            humidityAccuracy: appSettings.humidityAccuracy,
            pressureUnit: pressureUnit,
            pressureAccuracy: appSettings.pressureAccuracy,
            language: appSettings.language
        )
    }

    private func unit(
        for variant: MeasurementDisplayVariant,
        appSettings: MeasurementServiceSettings
    ) -> String {
        switch variant.type {
        case .temperature:
            let temperatureUnit = variant.temperatureUnit ?? appSettings.temperatureUnit.temperatureUnit
            return temperatureUnit.symbol
        case .humidity:
            let humidityUnit = variant.humidityUnit ?? appSettings.humidityUnit
            switch humidityUnit {
            case .percent:
                return RuuviLocalization.humidityRelativeUnit
            case .gm3:
                return RuuviLocalization.gm³
            case .dew:
                let temperatureUnit = variant.temperatureUnit ?? appSettings.temperatureUnit.temperatureUnit
                return temperatureUnit.symbol
            }
        case .pressure:
            let pressureUnit = variant.pressureUnit ?? appSettings.pressureUnit
            return pressureUnit.ruuviSymbol
        case .movementCounter,
             .aqi,
             .voc,
             .nox,
             .measurementSequenceNumber:
            return ""
        case .voltage:
            return RuuviLocalization.v
        case .accelerationX,
             .accelerationY,
             .accelerationZ:
            return RuuviLocalization.g
        case .co2:
            return RuuviLocalization.unitCo2
        case .pm10:
            return RuuviLocalization.unitPm10
        case .pm25:
            return RuuviLocalization.unitPm25
        case .pm40:
            return RuuviLocalization.unitPm40
        case .pm100:
            return RuuviLocalization.unitPm100
        case .luminosity:
            return RuuviLocalization.unitLuminosity
        case .soundInstant,
             .soundAverage,
             .soundPeak:
            return RuuviLocalization.unitSound
        case .rssi:
            return ""
        default:
            return ""
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func shortName(for variant: MeasurementDisplayVariant) -> String {
        switch variant.type {
        case .temperature:
            return RuuviLocalization.temperature
        case .humidity:
            let humidityUnit = variant.humidityUnit ?? .percent
            switch humidityUnit {
            case .percent:
                return RuuviLocalization.relHumidity
            case .gm3:
                return RuuviLocalization.absHumidity
            case .dew:
                return RuuviLocalization.dewpoint
            }
        case .pressure:
            return RuuviLocalization.pressure
        case .movementCounter:
            return RuuviLocalization.movements
        case .voltage:
            return RuuviLocalization.battery
        case .rssi:
            return RuuviLocalization.signalStrength
        case .accelerationX:
            return RuuviLocalization.accX
        case .accelerationY:
            return RuuviLocalization.accY
        case .accelerationZ:
            return RuuviLocalization.accZ
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.co2
        case .pm10:
            return RuuviLocalization.pm10
        case .pm25:
            return RuuviLocalization.pm25
        case .pm40:
            return RuuviLocalization.pm40
        case .pm100:
            return RuuviLocalization.pm100
        case .nox:
            return RuuviLocalization.nox
        case .voc:
            return RuuviLocalization.voc
        case .soundInstant:
            return RuuviLocalization.soundInstant
        case .soundAverage:
            return RuuviLocalization.soundAvg
        case .soundPeak:
            return RuuviLocalization.soundPeak
        case .luminosity:
            return RuuviLocalization.light
        case .measurementSequenceNumber:
            return RuuviLocalization.measSeqNumber
        default:
            return ""
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private func displayNameWithUnit(
        for variant: MeasurementDisplayVariant,
        appSettings: MeasurementServiceSettings
    ) -> String {
        switch variant.type {
        case .temperature:
            let temperatureUnit = variant.temperatureUnit ?? appSettings.temperatureUnit.temperatureUnit
            return RuuviLocalization.temperatureWithUnit(temperatureUnit.symbol)
        case .humidity:
            let humidityUnit = variant.humidityUnit ?? appSettings.humidityUnit
            if humidityUnit == .dew {
                let temperatureUnit = variant.temperatureUnit ?? appSettings.temperatureUnit.temperatureUnit
                return shortName(for: variant) + " (\(temperatureUnit.symbol))"
            }
            return shortName(for: variant) + " (\(unit(for: variant, appSettings: appSettings)))"
        case .pressure:
            let pressureUnit = variant.pressureUnit ?? appSettings.pressureUnit
            return RuuviLocalization.pressureWithUnit(pressureUnit.ruuviSymbol)
        case .movementCounter:
            return RuuviLocalization.movements
        case .voltage:
            return RuuviLocalization.battery + " (\(RuuviLocalization.v))"
        case .accelerationX,
             .accelerationY,
             .accelerationZ:
            return shortName(for: variant) + " (\(RuuviLocalization.g))"
        case .aqi:
            return RuuviLocalization.airQuality
        case .co2:
            return RuuviLocalization.co2WithUnit(RuuviLocalization.unitCo2)
        case .pm10:
            return RuuviLocalization.pm10WithUnit(RuuviLocalization.unitPm10)
        case .pm25:
            return RuuviLocalization.pm25WithUnit(RuuviLocalization.unitPm25)
        case .pm40:
            return RuuviLocalization.pm40WithUnit(RuuviLocalization.unitPm40)
        case .pm100:
            return RuuviLocalization.pm100WithUnit(RuuviLocalization.unitPm100)
        case .voc:
            return RuuviLocalization.vocWithUnit(RuuviLocalization.unitVoc)
        case .nox:
            return RuuviLocalization.noxWithUnit(RuuviLocalization.unitNox)
        case .soundInstant:
            return RuuviLocalization.soundInstantWithUnit(RuuviLocalization.unitSound)
        case .soundAverage:
            return RuuviLocalization.soundAverageWithUnit(RuuviLocalization.unitSound)
        case .soundPeak:
            return RuuviLocalization.soundPeakWithUnit(RuuviLocalization.unitSound)
        case .luminosity:
            return RuuviLocalization.luminosityWithUnit(RuuviLocalization.unitLuminosity)
        case .rssi:
            return RuuviLocalization.signalStrengthWithUnit()
        default:
            return shortName(for: variant)
        }
    }

    private func resolvedDeviceType(for entry: WidgetEntry) -> RuuviDeviceType {
        if entry.config.ruuviWidgetTag?.deviceType == .ruuviAir {
            return .ruuviAir
        }

        guard let version = entry.record?.version else {
            return .unknown
        }

        let format = RuuviDataFormat.dataFormat(from: version)
        return (format == .e1 || format == .v6) ? .ruuviAir : .unknown
    }

    private func availableVariants(for deviceType: RuuviDeviceType) -> [MeasurementDisplayVariant] {
        orderedMeasurementTypes(for: deviceType).flatMap { type in
            variants(for: type)
        }
    }

    private func orderedMeasurementTypes(for deviceType: RuuviDeviceType) -> [MeasurementType] {
        if deviceType == .ruuviAir {
            return MeasurementDisplayDefaults.airMeasurementOrder
        }
        return MeasurementDisplayDefaults.tagMeasurementOrder
    }

    private func variants(for type: MeasurementType) -> [MeasurementDisplayVariant] {
        switch type {
        case .temperature:
            return [
                MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius),
                MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit),
                MeasurementDisplayVariant(type: .temperature, temperatureUnit: .kelvin),
            ]
        case .humidity:
            return [
                MeasurementDisplayVariant(type: .humidity, humidityUnit: .percent),
                MeasurementDisplayVariant(type: .humidity, humidityUnit: .gm3),
                MeasurementDisplayVariant(type: .humidity, humidityUnit: .dew),
            ]
        case .pressure:
            return [
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .newtonsPerMetersSquared),
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .hectopascals),
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .millimetersOfMercury),
                MeasurementDisplayVariant(type: .pressure, pressureUnit: .inchesOfMercury),
            ]
        default:
            return [MeasurementDisplayVariant(type: type)]
        }
    }

    private func resolvedVisibleVariants(
        availableVariants: [MeasurementDisplayVariant],
        cloudSettings: RuuviCloudSensorSettings?,
        appSettings: MeasurementServiceSettings
    ) -> [MeasurementDisplayVariant] {
        let preferenceVariants = uniqueOrderedVariants(
            (cloudSettings?.displayOrderCodes ?? []).compactMap { code in
                guard let visibilityCode = RuuviCloudSensorVisibilityCode.parse(code) else {
                    return nil
                }
                return normalizedVariant(
                    visibilityCode.variant,
                    appSettings: appSettings
                )
            }
        )

        if cloudSettings?.defaultDisplayOrder == false, !preferenceVariants.isEmpty {
            let visible = preferenceVariants.filter { variant in
                availableVariants.contains(variant)
            }
            return visible.isEmpty ? availableVariants : visible
        }

        let preferredSet = Set(preferenceVariants)
        let visible = availableVariants.filter { variant in
            isDefaultVisible(
                variant,
                appSettings: appSettings
            ) || preferredSet.contains(variant)
        }

        return visible.isEmpty ? availableVariants : visible
    }

    private func uniqueOrderedVariants(
        _ variants: [MeasurementDisplayVariant]
    ) -> [MeasurementDisplayVariant] {
        var seen = Set<MeasurementDisplayVariant>()
        return variants.filter { variant in
            seen.insert(variant).inserted
        }
    }

    private func isDefaultVisible(
        _ variant: MeasurementDisplayVariant,
        appSettings: MeasurementServiceSettings
    ) -> Bool {
        switch variant.type {
        case .temperature:
            let preferred = appSettings.temperatureUnit.temperatureUnit
            return (variant.temperatureUnit ?? preferred) == preferred
        case .humidity:
            let preferred = appSettings.humidityUnit
            return (variant.humidityUnit ?? preferred) == preferred
        case .pressure:
            let preferred = appSettings.pressureUnit
            return (variant.pressureUnit ?? preferred) == preferred
        default:
            return !VisibilityDefaults.hiddenTypes.contains(variant.type)
        }
    }

    private func hasValue(
        for variant: MeasurementDisplayVariant,
        record: RuuviTagSensorRecord,
        sensorSettings: SensorSettings?,
        appSettings: MeasurementServiceSettings
    ) -> Bool {
        let value = formattedValue(
            for: variant,
            from: record,
            sensorSettings: sensorSettings,
            appSettings: appSettings
        )
        return value != "-" && !value.isEmpty
    }

    private func variantIdentifier(_ variant: MeasurementDisplayVariant) -> String {
        if let code = variant.cloudVisibilityCode {
            return code.rawValue
        }

        let temperatureComponent: String = {
            guard let temperatureUnit = variant.temperatureUnit else {
                return "-"
            }
            switch temperatureUnit {
            case .celsius:
                return "c"
            case .fahrenheit:
                return "f"
            case .kelvin:
                return "k"
            }
        }()

        let humidityComponent: String = {
            guard let humidityUnit = variant.humidityUnit else {
                return "-"
            }
            switch humidityUnit {
            case .percent:
                return "percent"
            case .gm3:
                return "gm3"
            case .dew:
                return "dew"
            }
        }()

        let pressureComponent: String = {
            guard let pressureUnit = variant.pressureUnit else {
                return "-"
            }
            switch pressureUnit {
            case .newtonsPerMetersSquared:
                return "pa"
            case .hectopascals:
                return "hpa"
            case .millimetersOfMercury:
                return "mmhg"
            case .inchesOfMercury:
                return "inhg"
            default:
                return "other"
            }
        }()

        return "\(variant.type)-\(temperatureComponent)-\(humidityComponent)-\(pressureComponent)"
    }

    private func temperatureUnit(from defaults: UserDefaults?) -> UnitTemperature {
        let temperatureUnitId = defaults?.integer(forKey: Constants.temperatureUnitKey.rawValue)
        switch temperatureUnitId {
        case 1:
            return .kelvin
        case 2:
            return .celsius
        case 3:
            return .fahrenheit
        default:
            return .celsius
        }
    }

    private func temperatureAccuracy(from defaults: UserDefaults?) -> MeasurementAccuracyType {
        let temperatureAccuracyKeyId = defaults?.integer(forKey: Constants.temperatureAccuracyKey.rawValue)
        switch temperatureAccuracyKeyId {
        case 0:
            return .zero
        case 1:
            return .one
        case 2:
            return .two
        default:
            return .two
        }
    }

    private func humidityUnit(from defaults: UserDefaults?) -> HumidityUnit {
        let humidityUnitId = defaults?.integer(forKey: Constants.humidityUnitKey.rawValue)
        switch humidityUnitId {
        case 0:
            return .percent
        case 1:
            return .gm3
        case 2:
            return .dew
        default:
            return .percent
        }
    }

    private func humidityAccuracy(from defaults: UserDefaults?) -> MeasurementAccuracyType {
        let humidityAccuracyKeyId = defaults?.integer(forKey: Constants.humidityAccuracyKey.rawValue)
        switch humidityAccuracyKeyId {
        case 0:
            return .zero
        case 1:
            return .one
        case 2:
            return .two
        default:
            return .two
        }
    }

    private func pressureUnit(from defaults: UserDefaults?) -> UnitPressure {
        let pressureUnitId = defaults?.integer(forKey: Constants.pressureUnitKey.rawValue)
        switch pressureUnitId {
        case UnitPressure.newtonsPerMetersSquared.hashValue:
            return .newtonsPerMetersSquared
        case UnitPressure.inchesOfMercury.hashValue:
            return .inchesOfMercury
        case UnitPressure.millimetersOfMercury.hashValue:
            return .millimetersOfMercury
        default:
            return .hectopascals
        }
    }

    private func pressureAccuracy(from defaults: UserDefaults?) -> MeasurementAccuracyType {
        let pressureAccuracyId = defaults?.integer(forKey: Constants.pressureAccuracyKey.rawValue)
        switch pressureAccuracyId {
        case 0:
            return .zero
        case 1:
            return .one
        case 2:
            return .two
        default:
            return .two
        }
    }
}

private extension UnitTemperature {
    var temperatureUnit: TemperatureUnit {
        switch self {
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        default:
            return .celsius
        }
    }
}

// swiftlint:enable file_length
