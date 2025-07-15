import RuuviOntology

enum MeasurementType: String {
    case rssi
    case temperature
    case humidity
    case pressure
    // v3 & v5
    case acceleration
    case voltage
    // v5
    case movementCounter
    case txPower
    // E1/V6
    case aqi
    case co2
    case pm25
    case pm10
    case nox
    case voc
    case luminosity
    case sound
}

extension MeasurementType {
    static var chartsCases: [MeasurementType] {
        [
            .temperature,
            .humidity,
            .pressure,
            .aqi,
            .co2,
            .pm25,
            .pm10,
            .nox,
            .voc,
            .luminosity,
            .sound,
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
            .sound,
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
        case .sound:
            return .sound(lower: 0, upper: 0)
        case .luminosity:
            return .luminosity(lower: 0, upper: 0)
        default:
            return .temperature(lower: 0, upper: 0)
        }
    }
}
