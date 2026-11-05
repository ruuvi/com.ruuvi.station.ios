import RuuviOntology
import SwiftUI
import RuuviLocalization

// MARK: - COLORS

// Necessary colors used on the widgets
extension Color {
    static let backgroundColor = Color("BackgroundColor", bundle: WidgetResources.bundle)
    static let dashboardBackgroundColor = RuuviColor.dashboardBG.swiftUIColor
    static let dashboardCardBackgroundColor = RuuviColor.dashboardCardBG.swiftUIColor
    static let dashboardTitleColor = RuuviColor.dashboardIndicatorBig.swiftUIColor
    static let bodyTextColor = Color("BodyTextColor", bundle: WidgetResources.bundle)
    static let sensorNameColor1 = Color("SensorNameColor1", bundle: WidgetResources.bundle)
    static let sensorNameColor2 = Color("SensorNameColor2", bundle: WidgetResources.bundle)
    static let unitTextColor = Color("UnitTextColor", bundle: WidgetResources.bundle)
}

// MARK: - LANGUAGE

public extension Language {
    var locale: Locale {
        switch self {
        case .english:
            Locale(identifier: "en_US")
        case .finnish:
            Locale(identifier: "fi")
        case .french:
            Locale(identifier: "fr")
        case .swedish:
            Locale(identifier: "sv")
        case .german:
            Locale(identifier: "de")
        case .polish:
            Locale(identifier: "pl")
        }
    }

}

// MARK: - HUMIDITY

extension HumidityUnit {
    var symbol: String {
        switch self {
        case .percent:
            RuuviLocalization.humidityRelativeUnit
        case .gm3:
            RuuviLocalization.gm³
        default:
            "°"
        }
    }
}

// MARK: - NUMBERS

extension Double {
    func round(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        let rounded = (self * divisor).rounded(.toNearestOrAwayFromZero) / divisor
        return rounded
    }

    var nsNumber: NSNumber {
        NSNumber(value: self)
    }
}

extension Int {
    var value: String {
        String(self)
    }

}

// MARK: - String

extension String {
    func substring(toIndex: Int) -> String {
        String(prefix(max(0, toIndex)))
    }
}
