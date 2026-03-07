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

    static func defaultFromSystemPreferences(
        userDefaults: UserDefaults = .standard,
        locale: Locale = .autoupdatingCurrent
    ) -> TemperatureUnit {
        if let value = userDefaults
            .string(forKey: "AppleTemperatureUnit")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() {
            if value.contains("fahrenheit") || value == "f" {
                return .fahrenheit
            }
            if value.contains("kelvin") || value == "k" {
                return .kelvin
            }
            if value.contains("celsius") || value == "c" {
                return .celsius
            }
        }

        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            switch locale.measurementSystem {
            case .us:
                return .fahrenheit
            default:
                return .celsius
            }
        }

        if let measurementSystem = (locale as NSLocale)
            .object(forKey: .measurementSystem) as? String {
            let normalizedMeasurementSystem = measurementSystem
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if normalizedMeasurementSystem == "u.s." || normalizedMeasurementSystem == "us" {
                return .fahrenheit
            }
            return .celsius
        }

        return .celsius
    }
}

public extension UnitTemperature {
    static func defaultFromSystemPreferences(
        userDefaults: UserDefaults = .standard,
        locale: Locale = .autoupdatingCurrent
    ) -> UnitTemperature {
        TemperatureUnit.defaultFromSystemPreferences(
            userDefaults: userDefaults,
            locale: locale
        ).unitTemperature
    }
}
