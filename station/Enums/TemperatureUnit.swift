import Foundation

enum TemperatureUnit {
    case kelvin
    case celsius
    case fahrenheit

    var unitTemperature: UnitTemperature {
        switch self {
        case .celsius:
            return .celsius
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        }
    }
}
