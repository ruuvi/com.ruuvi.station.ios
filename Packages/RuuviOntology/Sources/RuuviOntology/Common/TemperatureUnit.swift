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
    static func fromSystemPreference(_ value: String?) -> TemperatureUnit? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }

        if value.contains("fahrenheit") || value == "f" {
            return .fahrenheit
        }
        if value.contains("kelvin") || value == "k" {
            return .kelvin
        }
        if value.contains("celsius") || value == "c" {
            return .celsius
        }

        return nil
    }

    static func fromMeasurementSystemIdentifier(_ value: String?) -> TemperatureUnit? {
        guard let value = value?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() else {
            return nil
        }

        if value == "u.s." || value == "us" {
            return .fahrenheit
        }

        return .celsius
    }

    @available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *)
    static func fromMeasurementSystem(_ measurementSystem: Locale.MeasurementSystem) -> TemperatureUnit {
        switch measurementSystem {
        case .us:
            return .fahrenheit
        default:
            return .celsius
        }
    }

    var alertRange: Range<Double> {
        let lowerTemp = Temperature(value: -40, unit: .celsius).converted(to: unitTemperature).value
        let upperTemp = Temperature(value: 85, unit: .celsius).converted(to: unitTemperature).value
        return .init(uncheckedBounds: (lowerTemp, upperTemp))
    }

    static func defaultFromSystemPreferences(
        userDefaults: UserDefaults = .standard,
        locale: Locale = .autoupdatingCurrent
    ) -> TemperatureUnit {
        if let temperatureUnit = fromSystemPreference(
            userDefaults.string(forKey: "AppleTemperatureUnit")
        ) {
            return temperatureUnit
        }

        return locale.usesMetricSystem ? .celsius : .fahrenheit
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
