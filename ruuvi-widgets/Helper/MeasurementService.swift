import Foundation
import Humidity
import RuuviOntology

public struct MeasurementServiceSettings {
    public let temperatureUnit: UnitTemperature
    public let humidityUnit: HumidityUnit
    public let pressureUnit: UnitPressure
    public let language: Language

    public init(
        temperatureUnit: UnitTemperature,
        humidityUnit: HumidityUnit,
        pressureUnit: UnitPressure,
        language: Language
    ) {
        self.temperatureUnit = temperatureUnit
        self.humidityUnit = humidityUnit
        self.pressureUnit = pressureUnit
        self.language = language
    }
}

final class MeasurementService: NSObject {

    public var settings: MeasurementServiceSettings

    private var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = settings.language.locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private let emptyValueString: String = "-"

    public init(settings: MeasurementServiceSettings) {
        self.settings = settings
        super.init()
    }
}

// MARK: - MeasurementsService
extension MeasurementService {

    public func temperature(for temperature: Temperature?) -> String {
        guard let temperature = temperature else {
            return emptyValueString
        }
        let value = temperature
            .converted(to: settings.temperatureUnit)
            .value
            .round(to: numberFormatter.maximumFractionDigits)
        return formattedValue(from: value)
    }

    public func pressure(for pressure: Pressure?) -> String {
        guard let pressure = pressure else {
            return emptyValueString
        }
        let value = pressure
            .converted(to: settings.pressureUnit)
            .value
            .round(to: numberFormatter.maximumFractionDigits)
        return formattedValue(from: value)
    }

    public func voltage(for voltage: Voltage?) -> String {
        guard let voltage = voltage else {
            return emptyValueString
        }
        let value = voltage
            .converted(to: .volts)
            .value
            .round(to: numberFormatter.maximumFractionDigits)
        return formattedValue(from: value)
    }

    public func humidity(for humidity: Humidity?,
                         temperature: Temperature?,
                         isDecimal: Bool) -> String {
        guard let humidity = humidity,
              let temperature = temperature else {
            return emptyValueString
        }
        let humidityWithTemperature = Humidity(
            value: humidity.value,
            unit: .relative(temperature: temperature)
        )

        var humidityValue: Double?

        switch settings.humidityUnit {
        case .percent:
            let value = humidityWithTemperature.value
            humidityValue = isDecimal
            ? value
                .round(to: numberFormatter.maximumFractionDigits)
            : (value * 100)
                .round(to: numberFormatter.maximumFractionDigits)
        case .gm3:
            humidityValue = humidityWithTemperature.converted(to: .absolute)
                .value
                .round(to: numberFormatter.maximumFractionDigits)
        case .dew:
            let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            humidityValue = dp?.converted(to: settings.temperatureUnit)
                .value
                .round(to: numberFormatter.maximumFractionDigits)
        }

        return formattedValue(from: humidityValue)
    }

    public func acceleration(for acceleration: Double?) -> String {
        guard let acceleration = acceleration else {
            return emptyValueString
        }
        let value = acceleration.round(to: numberFormatter.maximumFractionDigits)
        return formattedValue(from: value)
    }

    public func movements(for movements: Int?) -> String {
        guard let movements = movements else {
            return emptyValueString
        }
        return movements.value
    }
}
// MARK: - MeasurementService Helper methods
extension MeasurementService {
    private func formattedValue(from value: Double?) -> String {
        guard let value = value,
              let formattedValue = numberFormatter.string(from: value.nsNumber) else {
            return emptyValueString
        }
        return formattedValue
    }
}
