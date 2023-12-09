import Foundation
import RuuviOntology
import RuuviLocalization

extension TemperatureUnit: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .celsius:
            return { _ in RuuviLocalization.TemperatureUnit.Celsius.title }
        case .fahrenheit:
            return { _ in RuuviLocalization.TemperatureUnit.Fahrenheit.title }
        case .kelvin:
            return { _ in RuuviLocalization.TemperatureUnit.Kelvin.title }
        }
    }
}

extension UnitTemperature: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .celsius:
            return { _ in RuuviLocalization.TemperatureUnit.Celsius.title }
        case .fahrenheit:
            return { _ in RuuviLocalization.TemperatureUnit.Fahrenheit.title }
        case .kelvin:
            return { _ in RuuviLocalization.TemperatureUnit.Kelvin.title }
        default:
            return { _ in RuuviLocalization.na }
        }
    }
}

// defaults range of temperature
extension TemperatureUnit {
    var alertRange: Range<Double> {
        let lowerTemp = Temperature(value: -40, unit: .celsius).converted(to: self.unitTemperature).value
        let upperTemp = Temperature(value: 85, unit: .celsius).converted(to: self.unitTemperature).value
        return .init(uncheckedBounds: (lowerTemp, upperTemp))
    }
}
