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
    func string(
        for humidity: Humidity?,
        temperature: Temperature?,
        allowSettings: Bool,
        unit: HumidityUnit
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

    // Always returns 2 decimal points fraction value.
    func string(for measurement: Double?) -> String
    // Returns based on minimum 0 and maximum 2 decimal points fraction value.
    func string(from value: Double?) -> String

    /// Returns rounded (toNearestOrAwayFromZero) value alongside
    /// max score and state. This function should be used only on Dashboard and
    /// Full Sensor card.
    func aqiString(
        for co2: Double?,
        pm25: Double?
    ) -> ( // swiftlint:disable:this large_tuple
        currentScore: Int,
        maxScore: Int,
        state: AirQualityState
    )

    /// Returns value for two decimal places alongside max score and state.
    /// Should be used on Graph, Alert settings, Info popup, Export.
    func aqi(
        for co2: Double?,
        pm25: Double?
    ) -> ( // swiftlint:disable:this large_tuple
        currentScore: Double,
        maxScore: Int,
        state: AirQualityState
    )

    func co2String(for carbonDiOxide: Double?) -> String
    func pm10String(for pm10: Double?) -> String
    func pm25String(for pm25: Double?) -> String
    func pm40String(for pm40: Double?) -> String
    func pm100String(for pm100: Double?) -> String
    func vocString(for voc: Double?) -> String
    func noxString(for nox: Double?) -> String
    func soundString(for sound: Double?) -> String
    func luminosityString(for luminosity: Double?) -> String

    // Common
    func double(for value: Double?) -> Double
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
