import RuuviOntology

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
}
