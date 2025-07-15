import RuuviOntology

extension AlertType {
    // swiftlint:disable:next cyclomatic_complexity
    func toMeasurementType() -> MeasurementType? {
        switch self {
        case .temperature:
            return .temperature
        case .relativeHumidity:
            return .humidity
        case .pressure:
            return .pressure
        case .movement:
            return .movementCounter
        case .carbonDioxide:
            return .co2
        case .pMatter25:
            return .pm25
        case .pMatter10:
            return .pm10
        case .nox:
            return .nox
        case .voc:
            return .voc
        case .sound:
            return .sound
        case .luminosity:
            return .luminosity
        default:
            return nil
        }
    }
}
