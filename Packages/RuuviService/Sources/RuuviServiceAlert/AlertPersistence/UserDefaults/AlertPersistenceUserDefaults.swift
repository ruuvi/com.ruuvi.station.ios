import Foundation
import RuuviOntology

// swiftlint:disable file_length type_body_length
class AlertPersistenceUserDefaults: AlertPersistence {
    private let prefs = UserDefaults.standard

    // temperature
    private let temperatureLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureLowerBoundUDKeyPrefix."
    private let temperatureUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureUpperBoundUDKeyPrefix."
    private let temperatureAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertIsOnUDKeyPrefix."
    private let temperatureAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertDescriptionUDKeyPrefix."
    private let temperatureAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertMuteTillDateUDKeyPrefix."
    private let temperatureAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertIsTriggeredUDKeyPrefix."
    private let temperatureAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.temperatureAlertTriggeredAtUDKeyPrefix."

    // Humidity
    private let humidityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityLowerBoundUDKeyPrefix."
    private let humidityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityUpperBoundUDKeyPrefix."
    private let humidityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityAlertIsOnUDKeyPrefix."
    private let humidityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.HumidityAlertDescriptionUDKeyPrefix."
    private let humidityAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.humidityAlertMuteTillDateUDKeyPrefix."
    private let humidityAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.humidityAlertIsTriggeredUDKeyPrefix."
    private let humidityAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.humidityAlertTriggeredAtUDKeyPrefix."

    // Humidity
    private let relativeHumidityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityLowerBoundUDKeyPrefix."
    private let relativeHumidityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityUpperBoundUDKeyPrefix."
    private let relativeHumidityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertIsOnUDKeyPrefix."
    private let relativeHumidityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertDescriptionUDKeyPrefix."
    private let relativeHumidityAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertMuteTillDateUDKeyPrefix."
    private let relativeHumidityAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertIsTriggeredUDKeyPrefix."
    private let relativeHumidityAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.relativeHumidityAlertTriggeredAtUDKeyPrefix."

    // dew point
    private let dewPointLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointLowerBoundUDKeyPrefix."
    private let dewPointUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointUpperBoundUDKeyPrefix."
    private let dewPointAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertIsOnUDKeyPrefix."
    private let dewPointAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertDescriptionUDKeyPrefix."
    private let dewPointAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertMuteTillDateUDKeyPrefix."
    private let dewPointAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertIsTriggeredUDKeyPrefix."
    private let dewPointAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.dewPointAlertTriggeredAtUDKeyPrefix."

    // pressure
    private let pressureLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureLowerBoundUDKeyPrefix."
    private let pressureUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureUpperBoundUDKeyPrefix."
    private let pressureAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertIsOnUDKeyPrefix."
    private let pressureAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertDescriptionUDKeyPrefix."
    private let pressureAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertMuteTillDateUDKeyPrefix."
    private let pressureAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertIsTriggeredUDKeyPrefix."
    private let pressureAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.pressureAlertTriggeredAtUDKeyPrefix."

    // signal
    private let signalLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalLowerBoundUDKeyPrefix."
    private let signalUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalUpperBoundUDKeyPrefix."
    private let signalAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertIsOnUDKeyPrefix."
    private let signalAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertDescriptionUDKeyPrefix."
    private let signalAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertMuteTillDateUDKeyPrefix."
    private let signalAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertIsTriggeredUDKeyPrefix."
    private let signalAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.signalAlertTriggeredAtUDKeyPrefix."

    // battery voltage
    private let batteryVoltageLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageLowerBoundUDKeyPrefix."
    private let batteryVoltageUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageUpperBoundUDKeyPrefix."
    private let batteryVoltageAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageAlertIsOnUDKeyPrefix."
    private let batteryVoltageAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageAlertDescriptionUDKeyPrefix."
    private let batteryVoltageAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageAlertMuteTillDateUDKeyPrefix."
    private let batteryVoltageAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageAlertIsTriggeredUDKeyPrefix."
    private let batteryVoltageAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.batteryVoltageAlertTriggeredAtUDKeyPrefix."

    // AQI
    private let aqiLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantLowerBoundUDKeyPrefix."
    private let aqiUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantUpperBoundUDKeyPrefix."
    private let aqiAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantAlertIsOnUDKeyPrefix."
    private let aqiAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantAlertDescriptionUDKeyPrefix."
    private let aqiAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantAlertMuteTillDateUDKeyPrefix."
    private let aqiAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantAlertIsTriggeredUDKeyPrefix."
    private let aqiAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.aqiInstantAlertTriggeredAtUDKeyPrefix."

    // carbon dioxide
    private let co2LowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2LowerBoundUDKeyPrefix."
    private let co2UpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2UpperBoundUDKeyPrefix."
    private let co2AlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2AlertIsOnUDKeyPrefix."
    private let co2AlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2AlertDescriptionUDKeyPrefix."
    private let co2AlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2AlertMuteTillDateUDKeyPrefix."
    private let co2AlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2AlertIsTriggeredUDKeyPrefix."
    private let co2AlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.co2AlertTriggeredAtUDKeyPrefix."

    // pm1
    private let pm1LowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1LowerBoundUDKeyPrefix."
    private let pm1UpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1UpperBoundUDKeyPrefix."
    private let pm1AlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1AlertIsOnUDKeyPrefix."
    private let pm1AlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1AlertDescriptionUDKeyPrefix."
    private let pm1AlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1AlertMuteTillDateUDKeyPrefix."
    private let pm1AlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1AlertIsTriggeredUDKeyPrefix."
    private let pm1AlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm1AlertTriggeredAtUDKeyPrefix."

    // pm2.5
    private let pm25LowerBoundUDKeyPrefix
        = "AlertPeristenceUserDefaults.pm2_5LowerBoundUDKeyPrefix."
    private let pm25UpperBoundUDKeyPrefix
        = "AlertPeristenceUserDefaults.pm2_5UpperBoundUDKeyPrefix."
    private let pm25AlertIsOnUDKeyPrefix
        = "AlertPeristenceUserDefaults.pm2_5AlertIsOnUDKeyPrefix."
    private let pm25AlertDescriptionUDKeyPrefix
        = "AlertPeristenceUserDefaults.pm2_5AlertDescriptionUDKeyPrefix."
    private let pm25AlertMuteTillDateUDKeyPrefix
        = "AlertPeristenceUserDefaults.pm2_5AlertMuteTillDateUDKeyPrefix."
    private let pm25AlertIsTriggeredUDKeyPrefix
        = "AlertPeristenceUserDefaults.pm2_5AlertIsTriggeredUDKeyPrefix."
    private let pm25AlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm2_5AlertTriggeredAtUDKeyPrefix."

    // pm4
    private let pm4LowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4LowerBoundUDKeyPrefix."
    private let pm4UpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4UpperBoundUDKeyPrefix."
    private let pm4AlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4AlertIsOnUDKeyPrefix."
    private let pm4AlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4AlertDescriptionUDKeyPrefix."
    private let pm4AlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4AlertMuteTillDateUDKeyPrefix."
    private let pm4AlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4AlertIsTriggeredUDKeyPrefix."
    private let pm4AlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm4AlertTriggeredAtUDKeyPrefix."

    // pm10
    private let pm10LowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10LowerBoundUDKeyPrefix."
    private let pm10UpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10UpperBoundUDKeyPrefix."
    private let pm10AlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10AlertIsOnUDKeyPrefix."
    private let pm10AlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10AlertDescriptionUDKeyPrefix."
    private let pm10AlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10AlertMuteTillDateUDKeyPrefix."
    private let pm10AlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10AlertIsTriggeredUDKeyPrefix."
    private let pm10AlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.pm10AlertTriggeredAtUDKeyPrefix."

    // voc
    private let vocLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocLowerBoundUDKeyPrefix."
    private let vocUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocUpperBoundUDKeyPrefix."
    private let vocAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocAlertIsOnUDKeyPrefix."
    private let vocAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocAlertDescriptionUDKeyPrefix."
    private let vocAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocAlertMuteTillDateUDKeyPrefix."
    private let vocAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocAlertIsTriggeredUDKeyPrefix."
    private let vocAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.vocAlertTriggeredAtUDKeyPrefix."

    // nox
    private let noxLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxLowerBoundUDKeyPrefix."
    private let noxUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxUpperBoundUDKeyPrefix."
    private let noxAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxAlertIsOnUDKeyPrefix."
    private let noxAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxAlertDescriptionUDKeyPrefix."
    private let noxAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxAlertMuteTillDateUDKeyPrefix."
    private let noxAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxAlertIsTriggeredUDKeyPrefix."
    private let noxAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.noxAlertTriggeredAtUDKeyPrefix."

    // sound instant
    private let soundInstantLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantLowerBoundUDKeyPrefix."
    private let soundInstantUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantUpperBoundUDKeyPrefix."
    private let soundInstantAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantAlertIsOnUDKeyPrefix."
    private let soundInstantAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantAlertDescriptionUDKeyPrefix."
    private let soundInstantAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantAlertMuteTillDateUDKeyPrefix."
    private let soundInstantAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantAlertIsTriggeredUDKeyPrefix."
    private let soundInstantAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundInstantAlertTriggeredAtUDKeyPrefix."

    // sound average
    private let soundAverageLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageLowerBoundUDKeyPrefix."
    private let soundAverageUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageUpperBoundUDKeyPrefix."
    private let soundAverageAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageAlertIsOnUDKeyPrefix."
    private let soundAverageAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageAlertDescriptionUDKeyPrefix."
    private let soundAverageAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageAlertMuteTillDateUDKeyPrefix."
    private let soundAverageAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageAlertIsTriggeredUDKeyPrefix."
    private let soundAverageAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundAverageAlertTriggeredAtUDKeyPrefix."

    // sound peak
    private let soundPeakLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakLowerBoundUDKeyPrefix."
    private let soundPeakUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakUpperBoundUDKeyPrefix."
    private let soundPeakAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakAlertIsOnUDKeyPrefix."
    private let soundPeakAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakAlertDescriptionUDKeyPrefix."
    private let soundPeakAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakAlertMuteTillDateUDKeyPrefix."
    private let soundPeakAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakAlertIsTriggeredUDKeyPrefix."
    private let soundPeakAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.soundPeakAlertTriggeredAtUDKeyPrefix."

    // luminosity
    private let luminosityLowerBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityLowerBoundUDKeyPrefix."
    private let luminosityUpperBoundUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityUpperBoundUDKeyPrefix."
    private let luminosityAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityAlertIsOnUDKeyPrefix."
    private let luminosityAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityAlertDescriptionUDKeyPrefix."
    private let luminosityAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityAlertMuteTillDateUDKeyPrefix."
    private let luminosityAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityAlertIsTriggeredUDKeyPrefix."
    private let luminosityAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.luminosityAlertTriggeredAtUDKeyPrefix."

    // connection
    private let connectionAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertIsOnUDKeyPrefix."
    private let connectionAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertDescriptionUDKeyPrefix."
    private let connectionAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertMuteTillDateUDKeyPrefix."
    private let connectionAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertIsTriggeredUDKeyPrefix."
    private let connectionAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.connectionAlertTriggeredAtUDKeyPrefix."

    // cloud connection
    private let cloudConnectionAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertIsOnUDKeyPrefix."
    private let cloudConnectionAlertUnseenDurationUDPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertUnseenDurationUDPrefix."
    private let cloudConnectionAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertDescriptionUDKeyPrefix."
    private let cloudConnectionAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertMuteTillDateUDKeyPrefix."
    private let cloudConnectionAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertIsTriggeredUDKeyPrefix."
    private let cloudConnectionAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.cloudConnectionAlertTriggeredAtUDKeyPrefix."

    // movement
    private let movementAlertIsOnUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertIsOnUDKeyPrefix."
    private let movementAlertCounterUDPrefix
        = "AlertPersistenceUserDefaults.movementAlertCounterUDPrefix."
    private let movementAlertDescriptionUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertDescriptionUDKeyPrefix."
    private let movementAlertMuteTillDateUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertMuteTillDateUDKeyPrefix."
    private let movementAlertIsTriggeredUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertIsTriggeredUDKeyPrefix."
    private let movementAlertTriggeredAtUDKeyPrefix
        = "AlertPersistenceUserDefaults.movementAlertTriggeredAtUDKeyPrefix."

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func alert(for uuid: String, of type: AlertType) -> AlertType? {
        switch type {
        case .temperature:
            if prefs.bool(forKey: temperatureAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid) {
                return .temperature(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .relativeHumidity:
            if prefs.bool(forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid) {
                return .relativeHumidity(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .humidity:
            if prefs.bool(forKey: humidityAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.data(forKey: humidityLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.data(forKey: humidityUpperBoundUDKeyPrefix + uuid),
               let lowerHumidity = KeyedArchiver.unarchive(lower, with: Humidity.self),
               let upperHumidity = KeyedArchiver.unarchive(upper, with: Humidity.self) {
                return .humidity(lower: lowerHumidity, upper: upperHumidity)
            } else {
                return nil
            }
        case .dewPoint:
            if prefs.bool(forKey: dewPointAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: dewPointLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: dewPointUpperBoundUDKeyPrefix + uuid) {
                return .dewPoint(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .pressure:
            if prefs.bool(forKey: pressureAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: pressureLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: pressureUpperBoundUDKeyPrefix + uuid) {
                return .pressure(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .signal:
            if prefs.bool(forKey: signalAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: signalLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: signalUpperBoundUDKeyPrefix + uuid) {
                return .signal(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .batteryVoltage:
            if prefs.bool(forKey: batteryVoltageAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: batteryVoltageLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: batteryVoltageUpperBoundUDKeyPrefix + uuid) {
                return .batteryVoltage(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .aqi:
            if prefs.bool(forKey: aqiAlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: aqiLowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: aqiUpperBoundUDKeyPrefix + uuid) {
                return .aqi(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .carbonDioxide:
            if prefs.bool(forKey: co2AlertIsOnUDKeyPrefix + uuid),
                let lower = prefs.optionalDouble(forKey: co2LowerBoundUDKeyPrefix + uuid),
                let upper = prefs.optionalDouble(forKey: co2UpperBoundUDKeyPrefix + uuid) {
                return .carbonDioxide(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .pMatter1:
            if prefs.bool(forKey: pm1AlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: pm1LowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: pm1UpperBoundUDKeyPrefix + uuid) {
                return .pMatter1(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .pMatter25:
            if prefs.bool(forKey: pm25AlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: pm25LowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: pm25UpperBoundUDKeyPrefix + uuid) {
                return .pMatter25(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .pMatter4:
            if prefs.bool(forKey: pm4AlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: pm4LowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: pm4UpperBoundUDKeyPrefix + uuid) {
                return .pMatter4(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .pMatter10:
            if prefs.bool(forKey: pm10AlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: pm10LowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: pm10UpperBoundUDKeyPrefix + uuid) {
                return .pMatter10(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .voc:
            if prefs.bool(forKey: vocAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(
                forKey: vocLowerBoundUDKeyPrefix + uuid
               ),
               let upper = prefs.optionalDouble(
                forKey: vocUpperBoundUDKeyPrefix + uuid
               ) {
                return .voc(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .nox:
            if prefs.bool(forKey: noxAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: noxLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: noxUpperBoundUDKeyPrefix + uuid) {
                return .nox(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .soundInstant:
            if prefs.bool(forKey: soundInstantAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: soundInstantLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: soundInstantUpperBoundUDKeyPrefix + uuid) {
                return .soundInstant(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .soundAverage:
            if prefs.bool(forKey: soundAverageAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: soundAverageLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: soundAverageUpperBoundUDKeyPrefix + uuid) {
                return .soundInstant(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .soundPeak:
            if prefs.bool(forKey: soundPeakAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: soundPeakLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: soundPeakUpperBoundUDKeyPrefix + uuid) {
                return .soundPeak(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .luminosity:
            if prefs.bool(forKey: luminosityAlertIsOnUDKeyPrefix + uuid),
               let lower = prefs.optionalDouble(forKey: luminosityLowerBoundUDKeyPrefix + uuid),
               let upper = prefs.optionalDouble(forKey: luminosityUpperBoundUDKeyPrefix + uuid) {
                return .luminosity(lower: lower, upper: upper)
            } else {
                return nil
            }
        case .connection:
            if prefs.bool(forKey: connectionAlertIsOnUDKeyPrefix + uuid) {
                return .connection
            } else {
                return nil
            }
        case .cloudConnection:
            if prefs.bool(forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid),
               let unseenDuration = prefs.optionalDouble(
                   forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid
               ) {
                return .cloudConnection(unseenDuration: unseenDuration)
            } else {
                return nil
            }
        case .movement:
            if prefs.bool(forKey: movementAlertIsOnUDKeyPrefix + uuid),
               let counter = prefs.optionalInt(forKey: movementAlertCounterUDPrefix + uuid) {
                return .movement(last: counter)
            } else {
                return nil
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func register(type: AlertType, for uuid: String) {
        switch type {
        case let .temperature(lower, upper):
            prefs.set(true, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
        case let .relativeHumidity(lower, upper):
            prefs.set(true, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
        case let .humidity(lower, upper):
            prefs.set(true, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: lower), forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: upper), forKey: humidityUpperBoundUDKeyPrefix + uuid)
        case let .dewPoint(lower, upper):
            prefs.set(true, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: dewPointLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: dewPointUpperBoundUDKeyPrefix + uuid)
        case let .pressure(lower, upper):
            prefs.set(true, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pressureUpperBoundUDKeyPrefix + uuid)
        case let .signal(lower, upper):
            prefs.set(true, forKey: signalAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: signalLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: signalUpperBoundUDKeyPrefix + uuid)
        case let .batteryVoltage(lower, upper):
            prefs.set(true, forKey: batteryVoltageAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: batteryVoltageLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: batteryVoltageUpperBoundUDKeyPrefix + uuid)
        case let .aqi(lower, upper):
            prefs.set(true, forKey: aqiAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: aqiLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: aqiUpperBoundUDKeyPrefix + uuid)
        case let .carbonDioxide(lower, upper):
            prefs.set(true, forKey: co2AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: co2LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: co2UpperBoundUDKeyPrefix + uuid)
        case let .pMatter1(lower, upper):
            prefs.set(true, forKey: pm1AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm1LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm1UpperBoundUDKeyPrefix + uuid)
        case let .pMatter25(lower, upper):
            prefs.set(true, forKey: pm25AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm25LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm25UpperBoundUDKeyPrefix + uuid)
        case let .pMatter4(lower, upper):
            prefs.set(true, forKey: pm4AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm4LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm4UpperBoundUDKeyPrefix + uuid)
        case let .pMatter10(lower, upper):
            prefs.set(true, forKey: pm10AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm10LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm10UpperBoundUDKeyPrefix + uuid)
        case let .voc(lower, upper):
            prefs.set(true, forKey: vocAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: vocLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: vocUpperBoundUDKeyPrefix + uuid)
        case let .nox(lower, upper):
            prefs.set(true, forKey: noxAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: noxLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: noxUpperBoundUDKeyPrefix + uuid)
        case let .soundInstant(lower, upper):
            prefs.set(true, forKey: soundInstantAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: soundInstantLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: soundInstantUpperBoundUDKeyPrefix + uuid)
        case let .soundAverage(lower, upper):
            prefs.set(true, forKey: soundAverageAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: soundAverageLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: soundAverageUpperBoundUDKeyPrefix + uuid)
        case let .soundPeak(lower, upper):
            prefs.set(true, forKey: soundPeakAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: soundPeakLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: soundPeakUpperBoundUDKeyPrefix + uuid)
        case let .luminosity(lower, upper):
            prefs.set(true, forKey: luminosityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: luminosityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: luminosityUpperBoundUDKeyPrefix + uuid)
        case .connection:
            prefs.set(true, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case let .cloudConnection(unseenDuration):
            prefs.set(true, forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid)
            prefs.set(unseenDuration, forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
        case let .movement(last):
            prefs.set(true, forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.set(last, forKey: movementAlertCounterUDPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func unregister(type: AlertType, for uuid: String) {
        switch type {
        case let .temperature(lower, upper):
            prefs.set(false, forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case let .relativeHumidity(lower, upper):
            prefs.set(false, forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case let .humidity(lower, upper):
            prefs.set(false, forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: lower), forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.set(KeyedArchiver.archive(object: upper), forKey: humidityUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case let .dewPoint(lower, upper):
            prefs.set(false, forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: dewPointLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: dewPointUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: dewPointAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: dewPointAlertTriggeredAtUDKeyPrefix + uuid)
        case let .pressure(lower, upper):
            prefs.set(false, forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pressureUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case let .signal(lower, upper):
            prefs.set(false, forKey: signalAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: signalLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: signalUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case let .batteryVoltage(lower, upper):
            prefs.set(false, forKey: batteryVoltageAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: batteryVoltageLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: batteryVoltageUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: batteryVoltageAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: batteryVoltageAlertTriggeredAtUDKeyPrefix + uuid)
        case let .aqi(lower, upper):
            prefs.set(false, forKey: aqiAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: aqiLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: aqiUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: aqiAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: aqiAlertTriggeredAtUDKeyPrefix + uuid)
        case let .carbonDioxide(lower, upper):
            prefs.set(false, forKey: co2AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: co2LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: co2UpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: co2AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: co2AlertTriggeredAtUDKeyPrefix + uuid)
        case let .pMatter1(lower, upper):
            prefs.set(false, forKey: pm1AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm1LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm1UpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: pm1AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: pm1AlertTriggeredAtUDKeyPrefix + uuid)
        case let .pMatter25(lower, upper):
            prefs.set(false, forKey: pm25AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm25LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm25UpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: pm25AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: pm25AlertTriggeredAtUDKeyPrefix + uuid)
        case let .pMatter4(lower, upper):
            prefs.set(false, forKey: pm4AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm4LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm4UpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: pm4AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: pm4AlertTriggeredAtUDKeyPrefix + uuid)
        case let .pMatter10(lower, upper):
            prefs.set(false, forKey: pm10AlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: pm10LowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: pm10UpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: pm10AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: pm10AlertTriggeredAtUDKeyPrefix + uuid)
        case let .voc(lower, upper):
            prefs.set(false, forKey: vocAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: vocLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: vocUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: vocAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: vocAlertTriggeredAtUDKeyPrefix + uuid)
        case let .nox(lower, upper):
            prefs.set(false, forKey: noxAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: noxLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: noxUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: noxAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: noxAlertTriggeredAtUDKeyPrefix + uuid)
        case let .soundInstant(lower, upper):
            prefs.set(false, forKey: soundInstantAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: soundInstantLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: soundInstantUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: soundInstantAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: soundInstantAlertTriggeredAtUDKeyPrefix + uuid)
        case let .soundAverage(lower, upper):
            prefs.set(false, forKey: soundAverageAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: soundAverageLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: soundAverageUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: soundAverageAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: soundAverageAlertTriggeredAtUDKeyPrefix + uuid)
        case let .soundPeak(lower, upper):
            prefs.set(false, forKey: soundPeakAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: soundPeakLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: soundPeakUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: soundPeakAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: soundPeakAlertTriggeredAtUDKeyPrefix + uuid)
        case let .luminosity(lower, upper):
            prefs.set(false, forKey: luminosityAlertIsOnUDKeyPrefix + uuid)
            prefs.set(lower, forKey: luminosityLowerBoundUDKeyPrefix + uuid)
            prefs.set(upper, forKey: luminosityUpperBoundUDKeyPrefix + uuid)
            prefs.set(false, forKey: luminosityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: luminosityAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            prefs.set(false, forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case let .cloudConnection(unseenDuration):
            prefs.set(false, forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid)
            prefs.set(unseenDuration, forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
            prefs.set(false, forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case let .movement(last):
            prefs.set(false, forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.set(last, forKey: movementAlertCounterUDPrefix + uuid)
            prefs.set(false, forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(nil, forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func remove(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.removeObject(forKey: temperatureAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.removeObject(forKey: relativeHumidityAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .humidity:
            prefs.removeObject(forKey: humidityAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.removeObject(forKey: dewPointAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: dewPointLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: dewPointUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: dewPointAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: dewPointAlertTriggeredAtUDKeyPrefix + uuid)
        case .pressure:
            prefs.removeObject(forKey: pressureAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case .signal:
            prefs.removeObject(forKey: signalAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .batteryVoltage:
            prefs.removeObject(forKey: batteryVoltageAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: batteryVoltageLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: batteryVoltageUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: batteryVoltageAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: batteryVoltageAlertTriggeredAtUDKeyPrefix + uuid)
        case .aqi:
            prefs.removeObject(forKey: aqiAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: aqiLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: aqiUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: aqiAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: aqiAlertTriggeredAtUDKeyPrefix + uuid)
        case .carbonDioxide:
            prefs.removeObject(forKey: co2AlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: co2LowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: co2UpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: co2AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: co2AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter1:
            prefs.removeObject(forKey: pm1AlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm1LowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm1UpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm1AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm1AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter25:
            prefs.removeObject(forKey: pm25AlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm25LowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm25UpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm25AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm25AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter4:
            prefs.removeObject(forKey: pm4AlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm4LowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm4UpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm4AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm4AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter10:
            prefs.removeObject(forKey: pm10AlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm10LowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm10UpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm10AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: pm10AlertTriggeredAtUDKeyPrefix + uuid)
        case .voc:
            prefs.removeObject(forKey: vocAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: vocLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: vocUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: vocAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: vocAlertTriggeredAtUDKeyPrefix + uuid)
        case .nox:
            prefs.removeObject(forKey: noxAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: noxLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: noxUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: noxAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: noxAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundInstant:
            prefs.removeObject(forKey: soundInstantAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundInstantLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundInstantUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundInstantAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundInstantAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundAverage:
            prefs.removeObject(forKey: soundAverageAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundAverageLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundAverageUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundAverageAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundAverageAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundPeak:
            prefs.removeObject(forKey: soundPeakAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundPeakLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundPeakUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundPeakAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: soundPeakAlertTriggeredAtUDKeyPrefix + uuid)
        case .luminosity:
            prefs.removeObject(forKey: luminosityAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: luminosityLowerBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: luminosityUpperBoundUDKeyPrefix + uuid)
            prefs.removeObject(forKey: luminosityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: luminosityAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            prefs.removeObject(forKey: connectionAlertIsOnUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.removeObject(forKey: cloudConnectionAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
            prefs.removeObject(forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case .movement:
            prefs.removeObject(forKey: movementAlertIsOnUDKeyPrefix + uuid)
            prefs.removeObject(forKey: movementAlertCounterUDPrefix + uuid)
            prefs.removeObject(forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.removeObject(forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func mute(type: AlertType, for uuid: String, till date: Date) {
        switch type {
        case .temperature:
            prefs.set(date, forKey: temperatureAlertMuteTillDateUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(date, forKey: relativeHumidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(date, forKey: humidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(date, forKey: dewPointAlertMuteTillDateUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(date, forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid)
        case .signal:
            prefs.set(date, forKey: signalAlertMuteTillDateUDKeyPrefix + uuid)
        case .batteryVoltage:
            prefs.set(date, forKey: batteryVoltageAlertMuteTillDateUDKeyPrefix + uuid)
        case .aqi:
            prefs.set(date, forKey: aqiAlertMuteTillDateUDKeyPrefix + uuid)
        case .carbonDioxide:
            prefs.set(date, forKey: co2AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter1:
            prefs.set(date, forKey: pm1AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter25:
            prefs.set(date, forKey: pm25AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter4:
            prefs.set(date, forKey: pm4AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter10:
            prefs.set(date, forKey: pm10AlertMuteTillDateUDKeyPrefix + uuid)
        case .voc:
            prefs.set(date, forKey: vocAlertMuteTillDateUDKeyPrefix + uuid)
        case .nox:
            prefs.set(date, forKey: noxAlertMuteTillDateUDKeyPrefix + uuid)
        case .soundInstant:
            prefs.set(date, forKey: soundInstantAlertMuteTillDateUDKeyPrefix + uuid)
        case .soundAverage:
            prefs.set(date, forKey: soundAverageAlertMuteTillDateUDKeyPrefix + uuid)
        case .soundPeak:
            prefs.set(date, forKey: soundPeakAlertMuteTillDateUDKeyPrefix + uuid)
        case .luminosity:
            prefs.set(date, forKey: luminosityAlertMuteTillDateUDKeyPrefix + uuid)
        case .connection:
            prefs.set(date, forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.set(date, forKey: cloudConnectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .movement:
            prefs.set(date, forKey: movementAlertMuteTillDateUDKeyPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func unmute(type: AlertType, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(nil, forKey: temperatureAlertMuteTillDateUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(nil, forKey: relativeHumidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(nil, forKey: humidityAlertMuteTillDateUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(nil, forKey: dewPointAlertMuteTillDateUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(nil, forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid)
        case .signal:
            prefs.set(nil, forKey: signalAlertMuteTillDateUDKeyPrefix + uuid)
        case .batteryVoltage:
            prefs.set(nil, forKey: batteryVoltageAlertMuteTillDateUDKeyPrefix + uuid)
        case .aqi:
            prefs.set(nil, forKey: aqiAlertMuteTillDateUDKeyPrefix + uuid)
        case .carbonDioxide:
            prefs.set(nil, forKey: co2AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter1:
            prefs.set(nil, forKey: pm1AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter25:
            prefs.set(nil, forKey: pm25AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter4:
            prefs.set(nil, forKey: pm4AlertMuteTillDateUDKeyPrefix + uuid)
        case .pMatter10:
            prefs.set(nil, forKey: pm10AlertMuteTillDateUDKeyPrefix + uuid)
        case .voc:
            prefs.set(nil, forKey: vocAlertMuteTillDateUDKeyPrefix + uuid)
        case .nox:
            prefs.set(nil, forKey: noxAlertMuteTillDateUDKeyPrefix + uuid)
        case .soundInstant:
            prefs.set(nil, forKey: soundInstantAlertMuteTillDateUDKeyPrefix + uuid)
        case .soundAverage:
            prefs.set(nil, forKey: soundAverageAlertMuteTillDateUDKeyPrefix + uuid)
        case .soundPeak:
            prefs.set(nil, forKey: soundPeakAlertMuteTillDateUDKeyPrefix + uuid)
        case .luminosity:
            prefs.set(nil, forKey: luminosityAlertMuteTillDateUDKeyPrefix + uuid)
        case .connection:
            prefs.set(nil, forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.set(nil, forKey: cloudConnectionAlertMuteTillDateUDKeyPrefix + uuid)
        case .movement:
            prefs.set(nil, forKey: movementAlertMuteTillDateUDKeyPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func mutedTill(type: AlertType, for uuid: String) -> Date? {
        switch type {
        case .temperature:
            return prefs.value(forKey: temperatureAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .relativeHumidity:
            return prefs.value(forKey: relativeHumidityAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .humidity:
            return prefs.value(forKey: humidityAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .dewPoint:
            return prefs.value(forKey: dewPointAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .pressure:
            return prefs.value(forKey: pressureAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .signal:
            return prefs.value(forKey: signalAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .batteryVoltage:
            return prefs.value(forKey: batteryVoltageAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .aqi:
            return prefs.value(forKey: aqiAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .carbonDioxide:
            return prefs.value(forKey: co2AlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .pMatter1:
            return prefs.value(forKey: pm1AlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .pMatter25:
            return prefs.value(forKey: pm25AlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .pMatter4:
            return prefs.value(forKey: pm4AlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .pMatter10:
            return prefs.value(forKey: pm10AlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .voc:
            return prefs.value(forKey: vocAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .nox:
            return prefs.value(forKey: noxAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .soundInstant:
            return prefs.value(forKey: soundInstantAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .soundAverage:
            return prefs.value(forKey: soundAverageAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .soundPeak:
            return prefs.value(forKey: soundPeakAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .luminosity:
            return prefs.value(forKey: luminosityAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .connection:
            return prefs.value(forKey: connectionAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .cloudConnection:
            return prefs.value(forKey: cloudConnectionAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        case .movement:
            return prefs.value(forKey: movementAlertMuteTillDateUDKeyPrefix + uuid) as? Date
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func trigger(type: AlertType, trigerred: Bool?, trigerredAt: String?, for uuid: String) {
        switch type {
        case .temperature:
            prefs.set(trigerred, forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.set(trigerred, forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .humidity:
            prefs.set(trigerred, forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.set(trigerred, forKey: dewPointAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: dewPointAlertTriggeredAtUDKeyPrefix + uuid)
        case .pressure:
            prefs.set(trigerred, forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case .signal:
            prefs.set(trigerred, forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .batteryVoltage:
            prefs.set(trigerred, forKey: batteryVoltageAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: batteryVoltageAlertTriggeredAtUDKeyPrefix + uuid)
        case .carbonDioxide:
            prefs.set(trigerred, forKey: co2AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: co2AlertTriggeredAtUDKeyPrefix + uuid)
        case .aqi:
            prefs.set(trigerred, forKey: aqiAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: aqiAlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter1:
            prefs.set(trigerred, forKey: pm1AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: pm1AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter25:
            prefs.set(trigerred, forKey: pm25AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: pm25AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter4:
            prefs.set(trigerred, forKey: pm4AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: pm4AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter10:
            prefs.set(trigerred, forKey: pm10AlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: pm10AlertTriggeredAtUDKeyPrefix + uuid)
        case .voc:
            prefs.set(trigerred, forKey: vocAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: vocAlertTriggeredAtUDKeyPrefix + uuid)
        case .nox:
            prefs.set(trigerred, forKey: noxAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: noxAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundInstant:
            prefs.set(trigerred, forKey: soundInstantAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: soundInstantAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundAverage:
            prefs.set(trigerred, forKey: soundAverageAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: soundAverageAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundPeak:
            prefs.set(trigerred, forKey: soundPeakAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: soundPeakAlertTriggeredAtUDKeyPrefix + uuid)
        case .luminosity:
            prefs.set(trigerred, forKey: luminosityAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: luminosityAlertTriggeredAtUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.set(trigerred, forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case .movement:
            prefs.set(trigerred, forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            prefs.set(trigerred, forKey: connectionAlertIsTriggeredUDKeyPrefix + uuid)
            prefs.set(trigerredAt, forKey: connectionAlertTriggeredAtUDKeyPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func triggered(for uuid: String, of type: AlertType) -> Bool? {
        switch type {
        case .temperature:
            prefs.bool(forKey: temperatureAlertIsTriggeredUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.bool(forKey: relativeHumidityAlertIsTriggeredUDKeyPrefix + uuid)
        case .humidity:
            prefs.bool(forKey: humidityAlertIsTriggeredUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.bool(forKey: dewPointAlertIsTriggeredUDKeyPrefix + uuid)
        case .pressure:
            prefs.bool(forKey: pressureAlertIsTriggeredUDKeyPrefix + uuid)
        case .signal:
            prefs.bool(forKey: signalAlertIsTriggeredUDKeyPrefix + uuid)
        case .batteryVoltage:
            prefs.bool(forKey: batteryVoltageAlertIsTriggeredUDKeyPrefix + uuid)
        case .aqi:
            prefs.bool(forKey: aqiAlertIsTriggeredUDKeyPrefix + uuid)
        case .carbonDioxide:
            prefs.bool(forKey: co2AlertIsTriggeredUDKeyPrefix + uuid)
        case .pMatter1:
            prefs.bool(forKey: pm1AlertIsTriggeredUDKeyPrefix + uuid)
        case .pMatter25:
            prefs.bool(forKey: pm25AlertIsTriggeredUDKeyPrefix + uuid)
        case .pMatter4:
            prefs.bool(forKey: pm4AlertIsTriggeredUDKeyPrefix + uuid)
        case .pMatter10:
            prefs.bool(forKey: pm10AlertIsTriggeredUDKeyPrefix + uuid)
        case .voc:
            prefs.bool(forKey: vocAlertIsTriggeredUDKeyPrefix + uuid)
        case .nox:
            prefs.bool(forKey: noxAlertIsTriggeredUDKeyPrefix + uuid)
        case .soundInstant:
            prefs.bool(forKey: soundInstantAlertIsTriggeredUDKeyPrefix + uuid)
        case .soundAverage:
            prefs.bool(forKey: soundAverageAlertIsTriggeredUDKeyPrefix + uuid)
        case .soundPeak:
            prefs.bool(forKey: soundPeakAlertIsTriggeredUDKeyPrefix + uuid)
        case .luminosity:
            prefs.bool(forKey: luminosityAlertIsTriggeredUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.bool(forKey: cloudConnectionAlertIsTriggeredUDKeyPrefix + uuid)
        case .movement:
            prefs.bool(forKey: movementAlertIsTriggeredUDKeyPrefix + uuid)
        case .connection:
            prefs.bool(forKey: connectionAlertIsTriggeredUDKeyPrefix + uuid)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func triggeredAt(for uuid: String, of type: AlertType) -> String? {
        switch type {
        case .temperature:
            prefs.string(forKey: temperatureAlertTriggeredAtUDKeyPrefix + uuid)
        case .relativeHumidity:
            prefs.string(forKey: relativeHumidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .humidity:
            prefs.string(forKey: humidityAlertTriggeredAtUDKeyPrefix + uuid)
        case .dewPoint:
            prefs.string(forKey: dewPointAlertTriggeredAtUDKeyPrefix + uuid)
        case .pressure:
            prefs.string(forKey: pressureAlertTriggeredAtUDKeyPrefix + uuid)
        case .signal:
            prefs.string(forKey: signalAlertTriggeredAtUDKeyPrefix + uuid)
        case .batteryVoltage:
            prefs.string(forKey: batteryVoltageAlertTriggeredAtUDKeyPrefix + uuid)
        case .aqi:
            prefs.string(forKey: aqiAlertTriggeredAtUDKeyPrefix + uuid)
        case .carbonDioxide:
            prefs.string(forKey: co2AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter1:
            prefs.string(forKey: pm1AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter25:
            prefs.string(forKey: pm25AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter4:
            prefs.string(forKey: pm4AlertTriggeredAtUDKeyPrefix + uuid)
        case .pMatter10:
            prefs.string(forKey: pm10AlertTriggeredAtUDKeyPrefix + uuid)
        case .voc:
            prefs.string(forKey: vocAlertTriggeredAtUDKeyPrefix + uuid)
        case .nox:
            prefs.string(forKey: noxAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundInstant:
            prefs.string(forKey: soundInstantAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundAverage:
            prefs.string(forKey: soundAverageAlertTriggeredAtUDKeyPrefix + uuid)
        case .soundPeak:
            prefs.string(forKey: soundPeakAlertTriggeredAtUDKeyPrefix + uuid)
        case .luminosity:
            prefs.string(forKey: luminosityAlertTriggeredAtUDKeyPrefix + uuid)
        case .cloudConnection:
            prefs.string(forKey: cloudConnectionAlertTriggeredAtUDKeyPrefix + uuid)
        case .movement:
            prefs.string(forKey: movementAlertTriggeredAtUDKeyPrefix + uuid)
        case .connection:
            prefs.string(forKey: connectionAlertTriggeredAtUDKeyPrefix + uuid)
        }
    }
}

// MARK: - Temperature

extension AlertPersistenceUserDefaults {
    func lowerCelsius(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }

    func upperCelsius(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }

    func setLower(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureLowerBoundUDKeyPrefix + uuid)
    }

    func setUpper(celsius: Double?, for uuid: String) {
        prefs.set(celsius, forKey: temperatureUpperBoundUDKeyPrefix + uuid)
    }

    func temperatureDescription(for uuid: String) -> String? {
        prefs.string(forKey: temperatureAlertDescriptionUDKeyPrefix + uuid)
    }

    func setTemperature(description: String?, for uuid: String) {
        prefs.set(description, forKey: temperatureAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Relative Humidity

extension AlertPersistenceUserDefaults {
    func lowerRelativeHumidity(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(relativeHumidity: Double?, for uuid: String) {
        prefs.set(relativeHumidity, forKey: relativeHumidityLowerBoundUDKeyPrefix + uuid)
    }

    func upperRelativeHumidity(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(relativeHumidity: Double?, for uuid: String) {
        prefs.set(relativeHumidity, forKey: relativeHumidityUpperBoundUDKeyPrefix + uuid)
    }

    func relativeHumidityDescription(for uuid: String) -> String? {
        prefs.string(forKey: relativeHumidityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setRelativeHumidity(description: String?, for uuid: String) {
        prefs.set(description, forKey: relativeHumidityAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Humidity

extension AlertPersistenceUserDefaults {
    func lowerHumidity(for uuid: String) -> Humidity? {
        guard let data = prefs.data(forKey: humidityLowerBoundUDKeyPrefix + uuid)
        else {
            return nil
        }
        return KeyedArchiver.unarchive(data, with: Humidity.self)
    }

    func setLower(humidity: Humidity?, for uuid: String) {
        if let humidity {
            prefs.set(KeyedArchiver.archive(object: humidity), forKey: humidityLowerBoundUDKeyPrefix + uuid)
        } else {
            prefs.set(nil, forKey: humidityLowerBoundUDKeyPrefix + uuid)
        }
    }

    func upperHumidity(for uuid: String) -> Humidity? {
        guard let data = prefs.data(forKey: humidityUpperBoundUDKeyPrefix + uuid)
        else {
            return nil
        }
        return KeyedArchiver.unarchive(data, with: Humidity.self)
    }

    func setUpper(humidity: Humidity?, for uuid: String) {
        if let humidity {
            prefs.set(KeyedArchiver.archive(object: humidity), forKey: humidityUpperBoundUDKeyPrefix + uuid)
        } else {
            prefs.set(nil, forKey: humidityUpperBoundUDKeyPrefix + uuid)
        }
    }

    func humidityDescription(for uuid: String) -> String? {
        prefs.string(forKey: humidityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setHumidity(description: String?, for uuid: String) {
        prefs.set(description, forKey: humidityAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Dew Point

extension AlertPersistenceUserDefaults {
    func lowerDewPoint(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: dewPointLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(dewPoint: Double?, for uuid: String) {
        prefs.set(dewPoint, forKey: dewPointLowerBoundUDKeyPrefix + uuid)
    }

    func upperDewPoint(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: dewPointUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(dewPoint: Double?, for uuid: String) {
        prefs.set(dewPoint, forKey: dewPointUpperBoundUDKeyPrefix + uuid)
    }

    func dewPointDescription(for uuid: String) -> String? {
        prefs.string(forKey: dewPointAlertDescriptionUDKeyPrefix + uuid)
    }

    func setDewPoint(description: String?, for uuid: String) {
        prefs.set(description, forKey: dewPointAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Pressure

extension AlertPersistenceUserDefaults {
    func lowerPressure(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pressureLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pressure: Double?, for uuid: String) {
        prefs.set(pressure, forKey: pressureLowerBoundUDKeyPrefix + uuid)
    }

    func upperPressure(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pressureUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pressure: Double?, for uuid: String) {
        prefs.set(pressure, forKey: pressureUpperBoundUDKeyPrefix + uuid)
    }

    func pressureDescription(for uuid: String) -> String? {
        prefs.string(forKey: pressureAlertDescriptionUDKeyPrefix + uuid)
    }

    func setPressure(description: String?, for uuid: String) {
        prefs.set(description, forKey: pressureAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - RSSI

extension AlertPersistenceUserDefaults {
    func lowerSignal(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: signalLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(signal: Double?, for uuid: String) {
        prefs.set(signal, forKey: signalLowerBoundUDKeyPrefix + uuid)
    }

    func upperSignal(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: signalUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(signal: Double?, for uuid: String) {
        prefs.set(signal, forKey: signalUpperBoundUDKeyPrefix + uuid)
    }

    func signalDescription(for uuid: String) -> String? {
        prefs.string(forKey: signalAlertDescriptionUDKeyPrefix + uuid)
    }

    func setSignal(description: String?, for uuid: String) {
        prefs.set(description, forKey: signalAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - AQI

extension AlertPersistenceUserDefaults {
    func lowerAQI(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: aqiLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(aqi: Double?, for uuid: String) {
        prefs.set(aqi, forKey: aqiLowerBoundUDKeyPrefix + uuid)
    }

    func upperAQI(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: aqiUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(aqi: Double?, for uuid: String) {
        prefs.set(aqi, forKey: aqiUpperBoundUDKeyPrefix + uuid)
    }

    func aqiDescription(for uuid: String) -> String? {
        prefs.string(forKey: aqiAlertDescriptionUDKeyPrefix + uuid)
    }

    func setAQI(description: String?, for uuid: String) {
        prefs.set(description, forKey: aqiAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Carbon Dioxide

extension AlertPersistenceUserDefaults {
    func lowerCarbonDioxide(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: co2LowerBoundUDKeyPrefix + uuid)
    }

    func setLower(carbonDioxide: Double?, for uuid: String) {
        prefs.set(carbonDioxide, forKey: co2LowerBoundUDKeyPrefix + uuid)
    }

    func upperCarbonDioxide(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: co2UpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(carbonDioxide: Double?, for uuid: String) {
        prefs.set(carbonDioxide, forKey: co2UpperBoundUDKeyPrefix + uuid)
    }

    func carbonDioxideDescription(for uuid: String) -> String? {
        prefs.string(forKey: co2AlertDescriptionUDKeyPrefix + uuid)
    }

    func setCarbonDioxide(description: String?, for uuid: String) {
        prefs.set(description, forKey: co2AlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Particulate Matter 1

extension AlertPersistenceUserDefaults {
    func lowerPM1(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm1LowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pm1: Double?, for uuid: String) {
        prefs.set(pm1, forKey: pm1LowerBoundUDKeyPrefix + uuid)
    }

    func upperPM1(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm1UpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pm1: Double?, for uuid: String) {
        prefs.set(pm1, forKey: pm1UpperBoundUDKeyPrefix + uuid)
    }

    func pm1Description(for uuid: String) -> String? {
        prefs.string(forKey: pm1AlertDescriptionUDKeyPrefix + uuid)
    }

    func setPM1(description: String?, for uuid: String) {
        prefs.set(description, forKey: pm1AlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Particulate Matter 2.5

extension AlertPersistenceUserDefaults {
    func lowerPM25(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm25LowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pm25: Double?, for uuid: String) {
        prefs.set(pm25, forKey: pm25LowerBoundUDKeyPrefix + uuid)
    }

    func upperPM25(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm25UpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pm25: Double?, for uuid: String) {
        prefs.set(pm25, forKey: pm25UpperBoundUDKeyPrefix + uuid)
    }

    func pm25Description(for uuid: String) -> String? {
        prefs.string(forKey: pm25AlertDescriptionUDKeyPrefix + uuid)
    }

    func setPM25(description: String?, for uuid: String) {
        prefs.set(description, forKey: pm25AlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Particulate Matter 4

extension AlertPersistenceUserDefaults {
    func lowerPM4(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm4LowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pm4: Double?, for uuid: String) {
        prefs.set(pm4, forKey: pm4LowerBoundUDKeyPrefix + uuid)
    }

    func upperPM4(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm4UpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pm4: Double?, for uuid: String) {
        prefs.set(pm4, forKey: pm4UpperBoundUDKeyPrefix + uuid)
    }

    func pm4Description(for uuid: String) -> String? {
        prefs.string(forKey: pm4AlertDescriptionUDKeyPrefix + uuid)
    }

    func setPM4(description: String?, for uuid: String) {
        prefs.set(description, forKey: pm4AlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Particulate Matter 10

extension AlertPersistenceUserDefaults {
    func lowerPM10(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm10LowerBoundUDKeyPrefix + uuid)
    }

    func setLower(pm10: Double?, for uuid: String) {
        prefs.set(pm10, forKey: pm10LowerBoundUDKeyPrefix + uuid)
    }

    func upperPM10(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: pm10UpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(pm10: Double?, for uuid: String) {
        prefs.set(pm10, forKey: pm10UpperBoundUDKeyPrefix + uuid)
    }

    func pm10Description(for uuid: String) -> String? {
        prefs.string(forKey: pm10AlertDescriptionUDKeyPrefix + uuid)
    }

    func setPM10(description: String?, for uuid: String) {
        prefs.set(description, forKey: pm10AlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - VOC

extension AlertPersistenceUserDefaults {
    func lowerVOC(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: vocLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(voc: Double?, for uuid: String) {
        prefs.set(voc, forKey: vocLowerBoundUDKeyPrefix + uuid)
    }

    func upperVOC(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: vocUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(voc: Double?, for uuid: String) {
        prefs.set(voc, forKey: vocUpperBoundUDKeyPrefix + uuid)
    }

    func vocDescription(for uuid: String) -> String? {
        prefs.string(forKey: vocAlertDescriptionUDKeyPrefix + uuid)
    }

    func setVOC(description: String?, for uuid: String) {
        prefs.set(description, forKey: vocAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - NOX

extension AlertPersistenceUserDefaults {
    func lowerNOX(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: noxLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(nox: Double?, for uuid: String) {
        prefs.set(nox, forKey: noxLowerBoundUDKeyPrefix + uuid)
    }

    func upperNOX(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: noxUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(nox: Double?, for uuid: String) {
        prefs.set(nox, forKey: noxUpperBoundUDKeyPrefix + uuid)
    }

    func noxDescription(for uuid: String) -> String? {
        prefs.string(forKey: noxAlertDescriptionUDKeyPrefix + uuid)
    }

    func setNOX(description: String?, for uuid: String) {
        prefs.set(description, forKey: noxAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Sound Instant

extension AlertPersistenceUserDefaults {

    func lowerSoundInstant(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: soundInstantLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(soundInstant: Double?, for uuid: String) {
        prefs.set(soundInstant, forKey: soundInstantLowerBoundUDKeyPrefix + uuid)
    }

    func upperSoundInstant(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: soundInstantUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(soundInstant: Double?, for uuid: String) {
        prefs.set(soundInstant, forKey: soundInstantUpperBoundUDKeyPrefix + uuid)
    }

    func soundInstantDescription(for uuid: String) -> String? {
        prefs.string(forKey: soundInstantAlertDescriptionUDKeyPrefix + uuid)
    }

    func setSoundInstant(description: String?, for uuid: String) {
        prefs.set(description, forKey: soundInstantAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Sound Average

extension AlertPersistenceUserDefaults {

    func lowerSoundAverage(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: soundAverageLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(soundAverage: Double?, for uuid: String) {
        prefs.set(soundAverage, forKey: soundAverageLowerBoundUDKeyPrefix + uuid)
    }

    func upperSoundAverage(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: soundAverageUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(soundAverage: Double?, for uuid: String) {
        prefs.set(soundAverage, forKey: soundAverageUpperBoundUDKeyPrefix + uuid)
    }

    func soundAverageDescription(for uuid: String) -> String? {
        prefs.string(forKey: soundAverageAlertDescriptionUDKeyPrefix + uuid)
    }

    func setSoundAverage(description: String?, for uuid: String) {
        prefs.set(description, forKey: soundAverageAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Sound Peak

extension AlertPersistenceUserDefaults {

    func lowerSoundPeak(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: soundPeakLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(soundPeak: Double?, for uuid: String) {
        prefs.set(soundPeak, forKey: soundPeakLowerBoundUDKeyPrefix + uuid)
    }

    func upperSoundPeak(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: soundPeakUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(soundPeak: Double?, for uuid: String) {
        prefs.set(soundPeak, forKey: soundPeakUpperBoundUDKeyPrefix + uuid)
    }

    func soundPeakDescription(for uuid: String) -> String? {
        prefs.string(forKey: soundPeakAlertDescriptionUDKeyPrefix + uuid)
    }

    func setSoundPeak(description: String?, for uuid: String) {
        prefs.set(description, forKey: soundPeakAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Luminosity

extension AlertPersistenceUserDefaults {

    func lowerLuminosity(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: luminosityLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(luminosity: Double?, for uuid: String) {
        prefs.set(luminosity, forKey: luminosityLowerBoundUDKeyPrefix + uuid)
    }

    func upperLuminosity(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: luminosityUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(luminosity: Double?, for uuid: String) {
        prefs.set(luminosity, forKey: luminosityUpperBoundUDKeyPrefix + uuid)
    }

    func luminosityDescription(for uuid: String) -> String? {
        prefs.string(forKey: luminosityAlertDescriptionUDKeyPrefix + uuid)
    }

    func setLuminosity(description: String?, for uuid: String) {
        prefs.set(description, forKey: luminosityAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Battery Voltage

extension AlertPersistenceUserDefaults {
    func lowerBatteryVoltage(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: batteryVoltageLowerBoundUDKeyPrefix + uuid)
    }

    func setLower(batteryVoltage: Double?, for uuid: String) {
        prefs.set(batteryVoltage, forKey: batteryVoltageLowerBoundUDKeyPrefix + uuid)
    }

    func upperBatteryVoltage(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: batteryVoltageUpperBoundUDKeyPrefix + uuid)
    }

    func setUpper(batteryVoltage: Double?, for uuid: String) {
        prefs.set(batteryVoltage, forKey: batteryVoltageUpperBoundUDKeyPrefix + uuid)
    }

    func batteryVoltageDescription(for uuid: String) -> String? {
        prefs.string(forKey: batteryVoltageAlertDescriptionUDKeyPrefix + uuid)
    }

    func setBatteryVoltage(description: String?, for uuid: String) {
        prefs.set(description, forKey: batteryVoltageAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Connection

extension AlertPersistenceUserDefaults {
    func connectionDescription(for uuid: String) -> String? {
        prefs.string(forKey: connectionAlertDescriptionUDKeyPrefix + uuid)
    }

    func setConnection(description: String?, for uuid: String) {
        prefs.set(description, forKey: connectionAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Cloud Connection

extension AlertPersistenceUserDefaults {
    func cloudConnectionUnseenDuration(for uuid: String) -> Double? {
        prefs.optionalDouble(forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
    }

    func setCloudConnection(unseenDuration: Double?, for uuid: String) {
        prefs.set(unseenDuration, forKey: cloudConnectionAlertUnseenDurationUDPrefix + uuid)
    }

    func cloudConnectionDescription(for uuid: String) -> String? {
        prefs.string(forKey: cloudConnectionAlertDescriptionUDKeyPrefix + uuid)
    }

    func setCloudConnection(description: String?, for uuid: String) {
        prefs.set(description, forKey: cloudConnectionAlertDescriptionUDKeyPrefix + uuid)
    }
}

// MARK: - Movement

extension AlertPersistenceUserDefaults {
    func movementCounter(for uuid: String) -> Int? {
        prefs.optionalInt(forKey: movementAlertCounterUDPrefix + uuid)
    }

    func setMovement(counter: Int?, for uuid: String) {
        prefs.set(counter, forKey: movementAlertCounterUDPrefix + uuid)
    }

    func movementDescription(for uuid: String) -> String? {
        prefs.string(forKey: movementAlertDescriptionUDKeyPrefix + uuid)
    }

    func setMovement(description: String?, for uuid: String) {
        prefs.set(description, forKey: movementAlertDescriptionUDKeyPrefix + uuid)
    }
}

// swiftlint:enable file_length type_body_length
