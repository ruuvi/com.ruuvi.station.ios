import Foundation
import Humidity
import RuuviOntology

public struct RuuviServiceMeasurementSettingsUnit {
    public let temperatureUnit: UnitTemperature
    public let humidityUnit: HumidityUnit
    public let pressureUnit: UnitPressure

    public init(
        temperatureUnit: UnitTemperature,
        humidityUnit: HumidityUnit,
        pressureUnit: UnitPressure
    ) {
        self.temperatureUnit = temperatureUnit
        self.humidityUnit = humidityUnit
        self.pressureUnit = pressureUnit
    }
}

public protocol RuuviServiceMeasurementDelegate: AnyObject {
    func measurementServiceDidUpdateUnit()
}

public protocol RuuviServiceMeasurement {
    var units: RuuviServiceMeasurementSettingsUnit { get set }
    func add(_ listener: RuuviServiceMeasurementDelegate)
    /// update units cache without notify listeners
    func updateUnits()

    // Temperature
    func double(for temperature: Temperature) -> Double
    func string(for temperature: Temperature?, allowSettings: Bool) -> String
    func stringWithoutSign(for temperature: Temperature?) -> String
    func stringWithoutSign(temperature: Double?) -> String

    // Humidity
    func double(
        for humidity: Humidity,
        temperature: Temperature,
        isDecimal: Bool
    ) -> Double?
    func string(
        for humidity: Humidity?,
        temperature: Temperature?,
        allowSettings: Bool
    ) -> String
    func stringWithoutSign(
        for humidity: Humidity?,
        temperature: Temperature?
    ) -> String
    func stringWithoutSign(humidity: Double?) -> String

    // Pressure
    func double(for pressure: Pressure) -> Double
    func string(for pressure: Pressure?, allowSettings: Bool) -> String
    func stringWithoutSign(for pressure: Pressure?) -> String
    func stringWithoutSign(pressure: Double?) -> String

    // Voltage
    func double(for voltage: Voltage) -> Double
    func string(for voltage: Voltage?) -> String

    // Offset correction
    func temperatureOffsetCorrection(for temperature: Double) -> Double
    func temperatureOffsetCorrectionString(for temperature: Double) -> String

    func humidityOffsetCorrection(for humidity: Double) -> Double
    func humidityOffsetCorrectionString(for humidity: Double) -> String

    func pressureOffsetCorrection(for pressure: Double) -> Double
    func pressureOffsetCorrectionString(for pressure: Double) -> String

    func string(for measurement: Double?) -> String
}

public extension RuuviServiceMeasurement {
    func double(for temperature: Temperature?) -> Double? {
        guard let temperature
        else {
            return nil
        }
        return double(for: temperature)
    }

    func double(
        for humidity: Humidity?,
        temperature: Temperature?,
        isDecimal: Bool
    ) -> Double? {
        guard let temperature,
              let humidity
        else {
            return nil
        }
        return double(
            for: humidity,
            temperature: temperature,
            isDecimal: isDecimal
        )
    }

    func double(for pressure: Pressure?) -> Double? {
        guard let pressure
        else {
            return nil
        }
        return double(for: pressure)
    }

    func double(for voltage: Voltage?) -> Double? {
        guard let voltage
        else {
            return nil
        }
        return double(for: voltage)
    }
}

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
