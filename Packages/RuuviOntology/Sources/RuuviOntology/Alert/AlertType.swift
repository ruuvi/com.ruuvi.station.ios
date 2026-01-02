import Foundation

public enum AlertType: CaseIterable, Hashable {
    case temperature(lower: Double, upper: Double) // celsius
    case humidity(lower: Humidity, upper: Humidity) // Abs.
    case relativeHumidity(lower: Double, upper: Double) // fraction of one
    case dewPoint(lower: Double, upper: Double) // celsius
    case pressure(lower: Double, upper: Double) // hPa
    case signal(lower: Double, upper: Double) // dB
    case batteryVoltage(lower: Double, upper: Double) // volts
    case aqi(lower: Double, upper: Double)
    case carbonDioxide(lower: Double, upper: Double) // ppm
    case pMatter1(lower: Double, upper: Double) // µg/m³
    case pMatter25(lower: Double, upper: Double) // µg/m³
    case pMatter4(lower: Double, upper: Double) // µg/m³
    case pMatter10(lower: Double, upper: Double) // µg/m³
    case voc(lower: Double, upper: Double) // VOC Index
    case nox(lower: Double, upper: Double) // NOx Index
    case soundInstant(lower: Double, upper: Double) // dB
    case soundPeak(lower: Double, upper: Double) // dB
    case soundAverage(lower: Double, upper: Double) // dB
    case luminosity(lower: Double, upper: Double) // lx
    case connection
    case cloudConnection(unseenDuration: Double)
    case movement(last: Int)

    public static var allCases: [AlertType] {
        [
            .temperature(lower: 0, upper: 0),
            .relativeHumidity(lower: 0, upper: 0),
            .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute),
            .dewPoint(lower: 0, upper: 0),
            .pressure(lower: 0, upper: 0),
            .signal(lower: 0, upper: 0),
            .batteryVoltage(lower: 0, upper: 0),
            .aqi(lower: 0, upper: 0),
            .carbonDioxide(lower: 0, upper: 0),
            .pMatter1(lower: 0, upper: 0),
            .pMatter25(lower: 0, upper: 0),
            .pMatter4(lower: 0, upper: 0),
            .pMatter10(lower: 0, upper: 0),
            .voc(lower: 0, upper: 0),
            .nox(lower: 0, upper: 0),
            .soundInstant(lower: 0, upper: 0),
            .soundPeak(lower: 0, upper: 0),
            .soundAverage(lower: 0, upper: 0),
            .luminosity(lower: 0, upper: 0),
            .connection,
            .cloudConnection(unseenDuration: 0),
            .movement(last: 0),
        ]
    }

    public var rawValue: String {
        switch self {
        case .temperature:
            return "temperature"
        case .humidity:
            return "absoluteHumidity"
        case .relativeHumidity:
            return "relativeHumidity"
        case .dewPoint:
            return "dewPoint"
        case .pressure:
            return "pressure"
        case .signal:
            return "signal"
        case .batteryVoltage:
            return "batteryVoltage"
        case .aqi:
            return "aqi"
        case .carbonDioxide:
            return "carbonDioxide"
        case .pMatter1:
            return "pMatter1"
        case .pMatter25:
            return "pMatter25"
        case .pMatter4:
            return "pMatter4"
        case .pMatter10:
            return "pMatter10"
        case .voc:
            return "voc"
        case .nox:
            return "nox"
        case .soundInstant:
            return "soundInstant"
        case .soundPeak:
            return "soundPeak"
        case .soundAverage:
            return "soundAverage"
        case .luminosity:
            return "luminosity"
        case .connection:
            return "connection"
        case .cloudConnection:
            return "cloudConnection"
        case .movement:
            return "movement"
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static public func alertType(from rawValue: String) -> AlertType? {
        switch rawValue {
        case "temperature":
            return .temperature(lower: 0, upper: 0)
        case "absoluteHumidity":
            return .humidity(lower: .zeroAbsolute, upper: .zeroAbsolute)
        case "relativeHumidity":
            return .relativeHumidity(lower: 0, upper: 0)
        case "dewPoint":
            return .dewPoint(lower: 0, upper: 0)
        case "pressure":
            return .pressure(lower: 0, upper: 0)
        case "signal":
            return .signal(lower: 0, upper: 0)
        case "batteryVoltage":
            return .batteryVoltage(lower: 0, upper: 0)
        case "aqi":
            return .aqi(lower: 0, upper: 0)
        case "carbonDioxide":
            return .carbonDioxide(lower: 0, upper: 0)
        case "pMatter1":
            return .pMatter1(lower: 0, upper: 0)
        case "pMatter25":
            return .pMatter25(lower: 0, upper: 0)
        case "pMatter4":
            return .pMatter4(lower: 0, upper: 0)
        case "pMatter10":
            return .pMatter10(lower: 0, upper: 0)
        case "voc":
            return .voc(lower: 0, upper: 0)
        case "nox":
            return .nox(lower: 0, upper: 0)
        case "soundInstant":
            return .soundInstant(lower: 0, upper: 0)
        case "soundPeak":
            return .soundPeak(lower: 0, upper: 0)
        case "soundAverage":
            return .soundAverage(lower: 0, upper: 0)
        case "luminosity":
            return .luminosity(lower: 0, upper: 0)
        case "connection":
            return .connection
        case "cloudConnection":
            return .cloudConnection(unseenDuration: 0)
        case "movement":
            return .movement(last: 0)
        default:
            return nil
        }
    }
}

public enum AlertState {
    case registered
    case empty
    case firing
}
