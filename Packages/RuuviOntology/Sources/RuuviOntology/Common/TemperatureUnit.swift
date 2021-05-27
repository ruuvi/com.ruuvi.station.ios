import Foundation
import RuuviOntology

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

//extension TemperatureUnit: SelectionItemProtocol {
//    public var title: String {
//        switch self {
//        case .celsius:
//            return "TemperatureUnit.Celsius.title".localized()
//        case .fahrenheit:
//            return "TemperatureUnit.Fahrenheit.title".localized()
//        case .kelvin:
//            return "TemperatureUnit.Kelvin.title".localized()
//        }
//    }
//}
//
//extension UnitTemperature: SelectionItemProtocol {
//    var title: String {
//        switch self {
//        case .celsius:
//            return "TemperatureUnit.Celsius.title".localized()
//        case .fahrenheit:
//            return "TemperatureUnit.Fahrenheit.title".localized()
//        case .kelvin:
//            return "TemperatureUnit.Kelvin.title".localized()
//        default:
//            return "N/A".localized()
//        }
//    }
//}

// defaults range of temperature
extension TemperatureUnit {
    public var alertRange: Range<Double> {
        let lowerTemp = Temperature(value: -40, unit: .celsius).converted(to: self.unitTemperature).value
        let upperTemp = Temperature(value: 85, unit: .celsius).converted(to: self.unitTemperature).value
        return .init(uncheckedBounds: (lowerTemp, upperTemp))
    }
}
