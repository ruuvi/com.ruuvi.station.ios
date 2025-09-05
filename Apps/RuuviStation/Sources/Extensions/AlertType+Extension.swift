import RuuviOntology
import RuuviLocalization

extension AlertType {
    // swiftlint:disable:next cyclomatic_complexity
    func toMeasurementType() -> MeasurementType? {
        switch self {
        case .temperature:
            return .temperature
        case .relativeHumidity:
            return .humidity(.percent)
        case .pressure:
            return .pressure
        case .movement:
            return .movementCounter
        case .aqi:
            return .aqi
        case .carbonDioxide:
            return .co2
        case .pMatter25:
            return .pm25
        case .pMatter10:
            return .pm100
        case .nox:
            return .nox
        case .voc:
            return .voc
        case .soundInstant:
            return .soundInstant
        case .luminosity:
            return .luminosity
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func title(with unit: String = "") -> String {
        switch self {
        case .temperature:
            return RuuviLocalization.temperatureWithUnit(unit)
        case .relativeHumidity:
            // We only support relative humidity alert on iOS
            return RuuviLocalization.relHumidity + " (\(HumidityUnit.percent.symbol))"
        case .pressure:
            return RuuviLocalization.pressureWithUnit(unit)
        case .movement:
            return RuuviLocalization.alertMovement
        case .aqi:
            return RuuviLocalization.airQuality
        case .carbonDioxide:
            return RuuviLocalization.co2WithUnit(unit)
        case .pMatter25:
            return RuuviLocalization.pm25WithUnit(unit)
        case .pMatter10:
            return RuuviLocalization.pm100WithUnit(unit)
        case .nox:
            return RuuviLocalization.nox
        case .voc:
            return RuuviLocalization.voc
        case .soundInstant:
            return RuuviLocalization.soundInstantWithUnit(unit)
        case .luminosity:
            return RuuviLocalization.luminosityWithUnit(unit)
        case .signal:
            return RuuviLocalization.signalStrengthWithUnit
        case.connection:
            return RuuviLocalization.alertConnection
        case .cloudConnection:
            return RuuviLocalization.alertCloudConnectionTitle
        default:
            return ""
        }
    }
}
