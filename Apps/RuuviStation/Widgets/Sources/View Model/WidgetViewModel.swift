import Foundation
import RuuviCloud
import RuuviOntology
import RuuviUser
import SwiftUI

public final class WidgetViewModel: ObservableObject {
    private let widgetAssembly = WidgetAssembly.shared.assembler.resolver
    private let appGroupDefaults = UserDefaults(suiteName: Constants.appGroupBundleId.rawValue)
    private let userDefaultsQueue = DispatchQueue(label: Constants.queue.rawValue)

    private var ruuviCloud: RuuviCloud!
    private var ruuviUser: RuuviUser!

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
            return
        }
        foceRefreshWidget(false)
        ruuviCloud.loadSensorsDense(
            for: nil,
            measurements: true,
            sharedToOthers: nil,
            sharedToMe: true,
            alerts: nil,
            settings: nil
        ).on(success: { sensors in
            let sensorsWithRecord = sensors.filter { $0.record != nil }
            completion(sensorsWithRecord)
        })
    }
}

// MARK: - Public methods

public extension WidgetViewModel {
    func isAuthorized() -> Bool {
        appGroupDefaults?.bool(forKey: Constants.isAuthorizedUDKey.rawValue) ?? false
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func getValue(
        from record: RuuviTagSensorRecord?,
        settings: SensorSettings?,
        config: RuuviTagSelectionIntent
    ) -> String {
        let measurementService = MeasurementService(settings: getAppSettings())

        var sensor: WidgetSensorEnum?
        if let identifier = config.sensorSelection?.identifier {
            sensor = WidgetSensorEnum(rawValue: identifier.bound)
        } else {
            sensor = WidgetSensorEnum(
                rawValue: config.sensor.rawValue
            )
        }
        guard let sensor = sensor,
                let record
        else {
            return "69.50" // Default value to show on the preview
        }

        switch sensor {
        case .temperature:
            let temperature = record.temperature?.plus(sensorSettings: settings)
            return measurementService.temperature(for: temperature)
        case .humidity:
            let temperature = record.temperature?.plus(sensorSettings: settings)
            let humidity = record.humidity?.plus(sensorSettings: settings)
            return measurementService.humidity(
                for: humidity,
                temperature: temperature,
                isDecimal: false
            )
        case .pressure:
            let pressure = record.pressure?.plus(sensorSettings: settings)
            return measurementService.pressure(for: pressure)
        case .movement_counter:
            return measurementService.movements(for: record.movementCounter)
        case .battery_voltage:
            return measurementService.voltage(for: record.voltage)
        case .acceleration_x:
            return measurementService.acceleration(for: record.acceleration?.x.value)
        case .acceleration_y:
            return measurementService.acceleration(for: record.acceleration?.y.value)
        case .acceleration_z:
            return measurementService.acceleration(for: record.acceleration?.z.value)
        case .air_quality:
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
        case .luminance:
            return measurementService.string(for: record.luminance)
        }
    }

    func getSensor(from config: RuuviTagSelectionIntent) -> WidgetSensorEnum? {
        if let identifier = config.sensorSelection?.identifier,
           let sensor = WidgetSensorEnum(rawValue: identifier.bound) {
            return sensor
        } else {
            return WidgetSensorEnum(rawValue: config.sensor.rawValue)
        }
    }

    func getUnit(for sensor: WidgetSensorEnum?) -> String {
        guard let sensor
        else {
            return "°C" // Default unit to show on the preview
        }
        let settings = getAppSettings()
        return sensor.unit(from: settings)
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

        var sensor: WidgetSensorEnum?
        if let identifier = entry.config.sensorSelection?.identifier {
            sensor = WidgetSensorEnum(rawValue: identifier.bound)
        } else {
            sensor = WidgetSensorEnum(
                rawValue: entry.config.sensor.rawValue
            )
        }
        guard let sensor = sensor
        else {
            return value
        }

        let unit = getUnit(
            for: sensor
        )
        return value + " " + unit
    }

    // Returns SF Symbol based on sensor since we
    // can not use Image in inline widget
    // swiftlint:disable:next cyclomatic_complexity
    internal func symbol(from entry: WidgetEntry) -> Image {
        var sensor: WidgetSensorEnum?
        if let identifier = entry.config.sensorSelection?.identifier {
            sensor = WidgetSensorEnum(rawValue: identifier.bound)
        } else {
            sensor = WidgetSensorEnum(
                rawValue: entry.config.sensor.rawValue
            )
        }
        guard let sensor = sensor
        else {
            return Image(systemName: "thermometer.medium.slash")
        }
        switch sensor {
        case .temperature:
            return Image(systemName: "thermometer.medium")
        case .humidity:
            return Image(systemName: "drop.circle")
        case .pressure:
            return Image(systemName: "wind.circle")
        case .movement_counter:
            return Image(systemName: "repeat.circle")
        case .acceleration_x,
                .acceleration_y,
                .acceleration_z:
            return Image(systemName: "move.3d")
        case .battery_voltage:
            return Image(systemName: "bolt.circle.fill")
        case .air_quality:
            return Image(systemName: "aqi.medium")
        case .co2:
            return Image(systemName: "cloud")
        case .nox:
            return Image(systemName: "smoke")
        case .voc:
            return Image(systemName: "wind")
        case .pm10:
            return Image(systemName: "circle.dotted")
        case .pm25:
            return Image(systemName: "circle.hexagongrid")
        case .pm40:
            return Image(systemName: "circle.grid.2x2")
        case .pm100:
            return Image(systemName: "circle.grid.3x3")
        case .luminance:
            return Image(systemName: "sun.max")
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
