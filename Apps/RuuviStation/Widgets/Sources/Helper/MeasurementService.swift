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
        formatter.minimumFractionDigits = 0
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
        guard let temperature
        else {
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
        guard let pressure
        else {
            return emptyValueString
        }
        let decimals = settings.pressureUnit.resolvedAccuracyValue(from: settings.pressureAccuracy)
        let value = settings.pressureUnit
            .convertedValue(from: pressure)
            .round(to: decimals)
        if settings.pressureUnit == .newtonsPerMetersSquared {
            return "\(Int(round(value)))"
        } else {
            pressureFormatter.maximumFractionDigits = decimals
            pressureFormatter.minimumFractionDigits = decimals
            return formattedValue(from: value, formatter: pressureFormatter)
        }
    }

    public func voltage(for voltage: Voltage?) -> String {
        guard let voltage
        else {
            return emptyValueString
        }
        let value = voltage
            .converted(to: .volts)
            .value
            .round(to: commonFormatter.maximumFractionDigits)
        return formattedValue(from: value, formatter: commonFormatter)
    }

    public func humidity(
        for humidity: Humidity?,
        temperature: Temperature?,
        isDecimal: Bool
    ) -> String {
        guard let humidity,
              let temperature
        else {
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
        guard let acceleration
        else {
            return emptyValueString
        }
        let value = acceleration.round(to: commonFormatter.maximumFractionDigits)
        return formattedValue(from: value, formatter: commonFormatter)
    }

    public func movements(for movements: Int?) -> String {
        guard let movements
        else {
            return emptyValueString
        }
        return movements.value
    }

    public func aqi(
        for co2: Double?,
        and pm25: Double?,
    ) -> String {
        let currentScore = calculateAQI(co2: co2, pm25: pm25)
            .rounded(.toNearestOrAwayFromZero)
        let intScrore = Int(exactly: currentScore) ?? 0
        return "\(intScrore)"
    }

    public func string(for double: Double?) -> String {
        guard let double
        else {
            return emptyValueString
        }
        return formattedValue(from: double, formatter: commonFormatter)
    }
}

// MARK: - MeasurementService Helper methods

extension MeasurementService {
    private func formattedValue(
        from value: Double?,
        formatter: NumberFormatter
    ) -> String {
        guard let value,
              let formattedValue = formatter.string(from: value.nsNumber)
        else {
            return emptyValueString
        }
        return formattedValue
    }

    // Important: This function should be in sync with `calculateAQI` function in RuuviServiceMeasurementImpl.
    // TODO: Find a way to share this logic without code duplication.
    private func calculateAQI(co2: Double?, pm25: Double?) -> Double {
        enum AQIConstants {
            static let maxValue = 100.0

            enum PM25 {
                static let range = 0.0...60.0
                static var scale: Double { AQIConstants.maxValue / (range.upperBound - range.lowerBound) }
            }

            enum CO2 {
                static let range = 420.0...2300.0
                static var scale: Double { AQIConstants.maxValue / (range.upperBound - range.lowerBound) }
            }
        }

        func clamped(_ value: Double, to range: ClosedRange<Double>) -> Double {
            min(max(value, range.lowerBound), range.upperBound)
        }

        guard let pm25, let co2, !pm25.isNaN, !co2.isNaN else {
            return .nan
        }

        let clampedPM25 = clamped(pm25, to: AQIConstants.PM25.range)
        let clampedCO2 = clamped(co2, to: AQIConstants.CO2.range)

        let dx = (clampedPM25 - AQIConstants.PM25.range.lowerBound) * AQIConstants.PM25.scale
        let dy = (clampedCO2 - AQIConstants.CO2.range.lowerBound) * AQIConstants.CO2.scale

        let distance = hypot(dx, dy)

        return clamped((AQIConstants.maxValue - distance), to: 0...AQIConstants.maxValue)
    }
}
