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
    func double(for humidity: Humidity,
                temperature: Temperature,
                isDecimal: Bool) -> Double?
    func string(for humidity: Humidity?,
                temperature: Temperature?,
                allowSettings: Bool) -> String
    func stringWithoutSign(for humidity: Humidity?,
                           temperature: Temperature?) -> String
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

extension RuuviServiceMeasurement {
    public func double(for temperature: Temperature?) -> Double? {
        guard let temperature = temperature else {
            return nil
        }
        return double(for: temperature)
    }

    public func double(for humidity: Humidity?,
                       temperature: Temperature?,
                       isDecimal: Bool) -> Double? {
        guard let temperature = temperature,
            let humidity = humidity else {
            return nil
        }
        return double(for: humidity,
                      temperature: temperature,
                      isDecimal: isDecimal)
    }

    public func double(for pressure: Pressure?) -> Double? {
        guard let pressure = pressure else {
            return nil
        }
        return double(for: pressure)
    }

    public func double(for voltage: Voltage?) -> Double? {
        guard let voltage = voltage else {
            return nil
        }
        return double(for: voltage)
    }
}

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
