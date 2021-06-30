import Foundation

public enum TemperatureUnit {
    case kelvin
    case celsius
    case fahrenheit

    public var unitTemperature: UnitTemperature {
        switch self {
        case .celsius:
            return .celsius
        case .fahrenheit:
            return .fahrenheit
        case .kelvin:
            return .kelvin
        }
    }

    public var symbol: String {
        return unitTemperature.symbol
    }
}

// defaults range of temperature
extension TemperatureUnit {
    public var alertRange: Range<Double> {
        let lowerTemp = Temperature(value: -40, unit: .celsius).converted(to: self.unitTemperature).value
        let upperTemp = Temperature(value: 85, unit: .celsius).converted(to: self.unitTemperature).value
        return .init(uncheckedBounds: (lowerTemp, upperTemp))
    }
}
