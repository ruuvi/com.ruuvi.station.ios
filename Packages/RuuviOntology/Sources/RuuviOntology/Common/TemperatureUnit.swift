import Foundation

public enum TemperatureUnit {
    case kelvin
    case celsius
    case fahrenheit

    public var unitTemperature: UnitTemperature {
        switch self {
        case .celsius:
            .celsius
        case .fahrenheit:
            .fahrenheit
        case .kelvin:
            .kelvin
        }
    }

    public var symbol: String {
        unitTemperature.symbol
    }
}

// defaults range of temperature
public extension TemperatureUnit {
    var alertRange: Range<Double> {
        let lowerTemp = Temperature(value: -40, unit: .celsius).converted(to: unitTemperature).value
        let upperTemp = Temperature(value: 85, unit: .celsius).converted(to: unitTemperature).value
        return .init(uncheckedBounds: (lowerTemp, upperTemp))
    }
}
