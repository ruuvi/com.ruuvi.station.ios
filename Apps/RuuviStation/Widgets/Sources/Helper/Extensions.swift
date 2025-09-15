import Humidity
import RuuviOntology
import SwiftUI

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

public extension Language {
    var locale: Locale {
        switch self {
        case .english:
            Locale(identifier: "en_US")
        case .russian:
            Locale(identifier: "ru_RU")
        case .finnish:
            Locale(identifier: "fi")
        case .french:
            Locale(identifier: "fr")
        case .swedish:
            Locale(identifier: "sv")
        case .german:
            Locale(identifier: "de")
        }
    }

    var humidityLanguage: HumiditySettings.Language {
        switch self {
        case .german:
            .en
        case .russian:
            .ru
        case .finnish:
            .fi
        case .french:
            .en
        case .swedish:
            .sv
        case .english:
            .en
        }
    }
}

// MARK: - HUMIDITY

extension HumidityUnit {
    var symbol: String {
        switch self {
        case .percent:
            "%"
        case .gm3:
            "g/m³"
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

    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(self)
    }

    var value: String {
        String(self)
    }

    var nsNumber: NSNumber {
        NSNumber(value: self)
    }
}

extension Int {
    var value: String {
        String(self)
    }

    var double: Double {
        Double(self)
    }
}

// MARK: - String

extension String? {
    var unwrapped: String {
        self ?? ""
    }
}

extension String {
    var localized: String {
        NSLocalizedString(self, comment: "")
    }
}

extension String {
    var bound: Int {
        Int(self) ?? 1 // Since first widget sensor case raw value is 1
    }

    var length: Int {
        count
    }

    subscript(i: Int) -> String {
        self[i ..< i + 1]
    }

    func substring(fromIndex: Int) -> String {
        self[min(fromIndex, length) ..< length]
    }

    func substring(toIndex: Int) -> String {
        self[0 ..< max(0, toIndex)]
    }

    subscript(r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (
            lower: max(0, min(length, r.lowerBound)),
            upper: min(length, max(0, r.upperBound))
        ))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}
