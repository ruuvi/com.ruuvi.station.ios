import Foundation
import Humidity
import RuuviOntology

public struct MeasurementServiceSettings {
    public let temperatureUnit: UnitTemperature
    public let temperatureAccuracy: MeasurementAccuracyType
    public let humidityUnit: HumidityUnit
    public let humidityAccuracy: MeasurementAccuracyType
    public let pressureUnit: UnitPressure
    public let pressureAccuracy: MeasurementAccuracyType
    public let language: Language

    public init(
        temperatureUnit: UnitTemperature,
        temperatureAccuracy: MeasurementAccuracyType,
        humidityUnit: HumidityUnit,
        humidityAccuracy: MeasurementAccuracyType,
        pressureUnit: UnitPressure,
        pressureAccuracy: MeasurementAccuracyType,
        language: Language
    ) {
        self.temperatureUnit = temperatureUnit
        self.temperatureAccuracy = temperatureAccuracy
        self.humidityUnit = humidityUnit
        self.humidityAccuracy = humidityAccuracy
        self.pressureAccuracy = pressureAccuracy
        self.pressureUnit = pressureUnit
        self.language = language
    }
}

final class MeasurementService: NSObject {

    public var settings: MeasurementServiceSettings

    private var commonFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }

    private var temperatureFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter
    }

    private var humidityFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
        return formatter
    }

    private var pressureFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.locale = Locale.autoupdatingCurrent
        formatter.numberStyle = .decimal
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
            .round(to: settings.temperatureAccuracy.value)
        temperatureFormatter.maximumFractionDigits = settings.temperatureAccuracy.value
        temperatureFormatter.minimumFractionDigits = settings.temperatureAccuracy.value
        return formattedValue(from: value, formatter: temperatureFormatter)
    }

    public func pressure(for pressure: Pressure?) -> String {
        guard let pressure = pressure else {
            return emptyValueString
        }
        let value = pressure
            .converted(to: settings.pressureUnit)
            .value
            .round(to: settings.pressureAccuracy.value)
        pressureFormatter.maximumFractionDigits = settings.pressureAccuracy.value
        pressureFormatter.minimumFractionDigits = settings.pressureAccuracy.value
        return formattedValue(from: value, formatter: pressureFormatter)
    }

    public func voltage(for voltage: Voltage?) -> String {
        guard let voltage = voltage else {
            return emptyValueString
        }
        let value = voltage
            .converted(to: .volts)
            .value
            .round(to: commonFormatter.maximumFractionDigits)
        return formattedValue(from: value, formatter: commonFormatter)
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
                .round(to: settings.humidityAccuracy.value)
            : (value * 100)
                .round(to: settings.humidityAccuracy.value)
        case .gm3:
            humidityValue = humidityWithTemperature.converted(to: .absolute)
                .value
                .round(to: settings.humidityAccuracy.value)
        case .dew:
            let dp = try? humidityWithTemperature.dewPoint(temperature: temperature)
            humidityValue = dp?.converted(to: settings.temperatureUnit)
                .value
                .round(to: settings.humidityAccuracy.value)
        }
        humidityFormatter.maximumFractionDigits = settings.humidityAccuracy.value
        humidityFormatter.minimumFractionDigits = settings.humidityAccuracy.value
        return formattedValue(from: humidityValue, formatter: humidityFormatter)
    }

    public func acceleration(for acceleration: Double?) -> String {
        guard let acceleration = acceleration else {
            return emptyValueString
        }
        let value = acceleration.round(to: commonFormatter.maximumFractionDigits)
        return formattedValue(from: value, formatter: commonFormatter)
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
    private func formattedValue(from value: Double?,
                                formatter: NumberFormatter) -> String {
        guard let value = value,
              let formattedValue = formatter.string(from: value.nsNumber) else {
            return emptyValueString
        }
        return formattedValue
    }
}
