import Foundation
import RuuviCloud
import RuuviOntology
import RuuviUser
import Localize_Swift

public final class WidgetViewModel: ObservableObject {
    private let widgetAssembly = WidgetAssembly.shared.assembler.resolver
    private let appGroupDefaults = UserDefaults(suiteName: Constants.appGroupBundleId.rawValue)

    private var ruuviCloud: RuuviCloud!
    private var ruuviUser: RuuviUser!

    init() {
        ruuviUser = widgetAssembly.resolve(RuuviUser.self)
        ruuviCloud = widgetAssembly.resolve(RuuviCloud.self)
//        setWidgetLanguage()
    }
}

// MARK: - Network calls
extension WidgetViewModel {

    public func fetchRuuviTags(completion: @escaping ([RuuviCloudSensorDense]) -> Void) {
        guard isAuthorized() else {
            return
        }
        ruuviCloud.loadSensorsDense(for: nil,
                                    measurements: true,
                                    sharedToOthers: nil,
                                    sharedToMe: true, alerts: nil).on(success: { sensors in
            let sensorsWithRecord = sensors.filter({ $0.record != nil })
            completion(sensorsWithRecord)
        })
    }
}

// MARK: - Public methods
extension WidgetViewModel {

    public func isAuthorized() -> Bool {
        return appGroupDefaults?.bool(forKey: Constants.isAuthorizedUDKey.rawValue) ?? false
    }

    public func getValue(from record: RuuviTagSensorRecord?,
                         settings: SensorSettings?,
                         config: RuuviTagSelectionIntent) -> String {
        let measurementService = MeasurementService(settings: getAppSettings())
        guard let sensor = WidgetSensorEnum(rawValue: config.sensor.rawValue),
              let record = record else {
            return "69.50" // Default value to show on the preview
        }
        switch sensor {
        case .temperature:
            let temperature = record.temperature?.plus(sensorSettings: settings)
            return measurementService.temperature(for: temperature)
        case .humidity:
            let temperature = record.temperature?.plus(sensorSettings: settings)
            let humidity = record.humidity?.plus(sensorSettings: settings)
            return measurementService.humidity(for: humidity,
                                               temperature: temperature,
                                               isDecimal: false)
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
        }
    }

    public func getUnit(for sensor: WidgetSensorEnum?) -> String {
        guard let sensor = sensor else {
            return "°C" // Default unit to show on the preview
        }
        let settings = getAppSettings()
        return sensor.unit(from: settings)
    }

    public func locale() -> Locale {
        return getLanguage().locale
    }
}

// MARK: - Private methods
extension WidgetViewModel {

    private func getAppSettings() -> MeasurementServiceSettings {
        let temperatureUnit = temperatureUnit(from: appGroupDefaults)
        let temperatureAccuracy = temperatureAccuracy(from: appGroupDefaults)
        let humidityUnit = humidityUnit(from: appGroupDefaults)
        let humidityAccuracy = humidityAccuracy(from: appGroupDefaults)
        let pressureUnit = pressureUnit(from: appGroupDefaults)
        let pressureAccuracy = pressureAccuracy(from: appGroupDefaults)
        return MeasurementServiceSettings(temperatureUnit: temperatureUnit,
                                          temperatureAccuracy: temperatureAccuracy,
                                          humidityUnit: humidityUnit,
                                          humidityAccuracy: humidityAccuracy,
                                          pressureUnit: pressureUnit,
                                          pressureAccuracy: pressureAccuracy,
                                          language: getLanguage())
    }

    private func getLanguage() -> Language {
        let languageCode = Bundle.main.preferredLocalizations[0]
        guard
              let language = Language(rawValue: languageCode) else {
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
