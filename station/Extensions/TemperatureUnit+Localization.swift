import Foundation
import RuuviLocalization
import RuuviOntology

extension TemperatureUnit: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .celsius:
            { _ in RuuviLocalization.TemperatureUnit.Celsius.title }
        case .fahrenheit:
            { _ in RuuviLocalization.TemperatureUnit.Fahrenheit.title }
        case .kelvin:
            { _ in RuuviLocalization.TemperatureUnit.Kelvin.title }
        }
    }
}

extension UnitTemperature: SelectionItemProtocol {
    var title: (String) -> String {
        switch self {
        case .celsius:
            { _ in RuuviLocalization.TemperatureUnit.Celsius.title }
        case .fahrenheit:
            { _ in RuuviLocalization.TemperatureUnit.Fahrenheit.title }
        case .kelvin:
            { _ in RuuviLocalization.TemperatureUnit.Kelvin.title }
        default:
            { _ in RuuviLocalization.na }
        }
    }
}

// defaults range of temperature
extension TemperatureUnit {
    var alertRange: Range<Double> {
        let lowerTemp = Temperature(value: -40, unit: .celsius).converted(to: unitTemperature).value
        let upperTemp = Temperature(value: 85, unit: .celsius).converted(to: unitTemperature).value
        return .init(uncheckedBounds: (lowerTemp, upperTemp))
    }
}
