import RuuviOntology
import RuuviLocalization

extension AlertType {
    // swiftlint:disable:next cyclomatic_complexity
    func toMeasurementType() -> MeasurementType? {
        switch self {
        case .temperature:
            return .temperature
        case .relativeHumidity:
            return .humidity
        case .humidity:
            return .humidity
        case .dewPoint:
            return .humidity
        case .batteryVoltage:
            return .voltage
        case .pressure:
            return .pressure
        case .movement:
            return .movementCounter
        case .aqi:
            return .aqi
        case .carbonDioxide:
            return .co2
        case .pMatter1:
            return .pm10
        case .pMatter25:
            return .pm25
        case .pMatter4:
            return .pm40
        case .pMatter10:
            return .pm100
        case .nox:
            return .nox
        case .voc:
            return .voc
        case .soundInstant:
            return .soundInstant
        case .soundPeak:
            return .soundPeak
        case .soundAverage:
            return .soundAverage
        case .luminosity:
            return .luminosity
        case .signal:
            return .rssi
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func title(with unit: String = "") -> String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperatureWithUnit(unit)
        case .relativeHumidity:
            // Relative humidity uses percent unit.
            return RuuviLocalization.relHumidity + " (\(HumidityUnit.percent.symbol))"
        case .humidity:
            return RuuviLocalization.absoluteHumidity + " (\(HumidityUnit.gm3.symbol))"
        case .dewPoint:
            if unit.isEmpty {
                return RuuviLocalization.dewpoint
            }
            return RuuviLocalization.dewpoint + " (\(unit))"
        case .pressure:
            return RuuviLocalization.pressureWithUnit(unit)
        case .movement:
            return RuuviLocalization.alertMovement
        case .aqi:
            return RuuviLocalization.airQuality
        case .carbonDioxide:
            return RuuviLocalization.co2WithUnit(unit)
        case .pMatter1:
            return RuuviLocalization.pm10WithUnit(unit)
        case .pMatter25:
            return RuuviLocalization.pm25WithUnit(unit)
        case .pMatter4:
            return RuuviLocalization.pm40WithUnit(unit)
        case .pMatter10:
            return RuuviLocalization.pm100WithUnit(unit)
        case .nox:
            return RuuviLocalization.nox
        case .voc:
            return RuuviLocalization.voc
        case .soundInstant:
            return RuuviLocalization.soundInstantWithUnit(unit)
        case .soundPeak:
            return RuuviLocalization.soundPeakWithUnit(unit)
        case .soundAverage:
            return RuuviLocalization.soundAverageWithUnit(unit)
        case .luminosity:
            return RuuviLocalization.luminosityWithUnit(unit)
        case .signal:
            return RuuviLocalization.signalStrengthWithUnit
        case .batteryVoltage:
            if unit.isEmpty {
                return RuuviLocalization.batteryVoltage
            }
            return RuuviLocalization.batteryVoltage + " (\(unit))"
        case.connection:
            return RuuviLocalization.alertConnection
        case .cloudConnection:
            return RuuviLocalization.alertCloudConnectionTitle
        }
    }
}
