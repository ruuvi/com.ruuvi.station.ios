import SwiftUI
import Humidity
import RuuviOntology

// MARK: - COLORS
// Necessary colors used on the widgets
extension Color {
    static let logoColor = Color("LogoColor")
    static let backgroundColor = Color("BackgroundColor")
    static let bodyTextColor = Color("BodyTextColor")
    static let sensorNameColor1 = Color("SensorNameColor1")
    static let sensorNameColor2 = Color("SensorNameColor2")
    static let unitTextColor = Color("UnitTextColor")
}

// MARK: - LANGUAGE
extension Language {
    public var locale: Locale {
        switch self {
        case .english:
            return Locale(identifier: "en_US")
        case .russian:
            return Locale(identifier: "ru_RU")
        case .finnish:
            return Locale(identifier: "fi")
        case .french:
            return Locale(identifier: "fr")
        case .swedish:
            return Locale(identifier: "sv")
        case .german:
            return Locale(identifier: "de")
        }
    }

    public var humidityLanguage: HumiditySettings.Language {
        switch self {
        case .german:
            return .en
        case .russian:
            return .ru
        case .finnish:
            return .fi
        case .french:
            return .en
        case .swedish:
            return .sv
        case .english:
            return .en
        }
    }
}

// MARK: - HUMIDITY

extension HumidityUnit {
    var symbol: String {
        switch self {
        case .percent:
            return "%"
        case .gm3:
            return "g/m³"
        default:
            return "°"
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

    var clean: String {
        return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }

    var value: String {
        return String(self)
    }

    var nsNumber: NSNumber {
        return NSNumber(value: self)
    }
}

extension Int {
    var value: String {
        return String(self)
    }

    var double: Double {
        return Double(self)
    }
}
// MARK: - String
extension Optional where Wrapped == String {
    var unwrapped: String {
        return self ?? ""
    }
}

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}

// MARK: - DateFormatter
extension DateFormatter {
    static let widgetDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        let dateString = formatter.string(from: Date())
        let amRange = dateString.range(of: formatter.amSymbol)
        let pmRange = dateString.range(of: formatter.pmSymbol)

        let is12HFormat = !(pmRange == nil && amRange == nil)

        formatter.dateFormat = is12HFormat ? "h:mm a": "hh:mm"
        return formatter
    }()
}
