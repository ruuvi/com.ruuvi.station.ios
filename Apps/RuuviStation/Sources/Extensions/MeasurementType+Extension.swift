import RuuviOntology

extension MeasurementType {
    static var chartsCases: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
            .aqi,
            .co2,
            .pm25,
            .nox,
            .voc,
            .luminosity,
            .soundInstant,
        ]
    }

    static var all: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
            .movementCounter,
            .aqi,
            .co2,
            .pm25,
            .pm10,
            .nox,
            .voc,
            .luminosity,
            .soundInstant,
        ]
    }
}

extension MeasurementType {
    // swiftlint:disable:next cyclomatic_complexity
    func toAlertType() -> AlertType {
        switch self {
        case .temperature:
            return .temperature(lower: 0, upper: 0)
        case .humidity:
            return .relativeHumidity(lower: 0, upper: 0)
        case .pressure:
            return .pressure(lower: 0, upper: 0)
        case .movementCounter:
            return .movement(last: 0)
        case .co2:
            return .carbonDioxide(lower: 0, upper: 0)
        case .pm25:
            return .pMatter25(lower: 0, upper: 0)
        case .pm10:
            return .pMatter10(lower: 0, upper: 0)
        case .nox:
            return .nox(lower: 0, upper: 0)
        case .voc:
            return .voc(lower: 0, upper: 0)
        case .soundInstant:
            return .soundInstant(lower: 0, upper: 0)
        case .luminosity:
            return .luminosity(lower: 0, upper: 0)
        default:
            return .temperature(lower: 0, upper: 0)
        }
    }
}
