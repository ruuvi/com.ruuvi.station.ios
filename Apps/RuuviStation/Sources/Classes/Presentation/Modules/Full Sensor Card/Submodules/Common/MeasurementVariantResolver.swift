import Foundation
import Humidity
import RuuviLocal
import RuuviOntology
import RuuviService

// swiftlint:disable:next type_body_length
struct MeasurementVariantResolver {
    struct ValueConfiguration {
        enum AQIPresentationStyle {
            case roundedScore
            case decimalValue
        }

        let aqiPresentation: AQIPresentationStyle
        let appliesTemperatureOffsetToHumidity: Bool

        static let measurementDetails = ValueConfiguration(
            aqiPresentation: .roundedScore,
            appliesTemperatureOffsetToHumidity: true
        )

        static let cardsGraph = ValueConfiguration(
            aqiPresentation: .decimalValue,
            appliesTemperatureOffsetToHumidity: false
        )
    }

    private let settings: RuuviLocalSettings
    private let measurementService: RuuviServiceMeasurement
    private let alertService: RuuviServiceAlert

    init(
        settings: RuuviLocalSettings,
        measurementService: RuuviServiceMeasurement,
        alertService: RuuviServiceAlert
    ) {
        self.settings = settings
        self.measurementService = measurementService
        self.alertService = alertService
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func value(
        for measurement: RuuviMeasurement,
        variant: MeasurementDisplayVariant,
        sensorSettings: SensorSettings?,
        configuration: ValueConfiguration = .measurementDetails
    ) -> Double? {
        if variant.type.isSameCase(as: .temperature) {
            guard let temp = measurement.temperature?.plus(sensorSettings: sensorSettings) else {
                return nil
            }
            let unit = variant.resolvedTemperatureUnit(
                default: settings.temperatureUnit.unitTemperature
            )
            return temp.converted(to: unit).value
        }

        if variant.type.isSameCase(as: .humidity) {
            guard
                let humidity = measurement.humidity?.plus(sensorSettings: sensorSettings),
                let temperature = humidityTemperature(
                    from: measurement,
                    sensorSettings: sensorSettings,
                    appliesOffset: configuration.appliesTemperatureOffsetToHumidity
                )
            else {
                return nil
            }

            let base = Humidity(
                value: humidity.value,
                unit: .relative(temperature: temperature)
            )
            switch variant.resolvedHumidityUnit(default: settings.humidityUnit) {
            case .percent:
                return base.value * 100
            case .gm3:
                return base.converted(to: .absolute).value
            case .dew:
                guard let dew = try? base.dewPoint(temperature: temperature) else {
                    return nil
                }
                let unit = variant.resolvedTemperatureUnit(
                    default: settings.temperatureUnit.unitTemperature
                )
                return dew.converted(to: unit).value
            }
        }

        if variant.type.isSameCase(as: .pressure) {
            guard let pressure = measurement.pressure?.plus(sensorSettings: sensorSettings) else {
                return nil
            }
            let unit = variant.resolvedPressureUnit(default: settings.pressureUnit)
            return unit.convertedValue(from: pressure)
        }

        switch variant.type {
        case .aqi:
            switch configuration.aqiPresentation {
            case .roundedScore:
                let (aqi, _, _) = measurementService.aqi(
                    for: measurement.co2,
                    pm25: measurement.pm25
                )
                return Double(aqi)
            case .decimalValue:
                return measurementService.aqi(
                    for: measurement.co2,
                    and: measurement.pm25
                )
            }
        case .co2:
            return measurementService.double(for: measurement.co2)
        case .pm10:
            return measurementService.double(for: measurement.pm1)
        case .pm25:
            return measurementService.double(for: measurement.pm25)
        case .pm40:
            return measurementService.double(for: measurement.pm4)
        case .pm100:
            return measurementService.double(for: measurement.pm10)
        case .voc:
            return measurementService.double(for: measurement.voc)
        case .nox:
            return measurementService.double(for: measurement.nox)
        case .luminosity:
            return measurementService.double(for: measurement.luminosity)
        case .soundInstant:
            return measurementService.double(for: measurement.soundInstant)
        case .soundAverage:
            return measurementService.double(for: measurement.soundAvg)
        case .soundPeak:
            return measurementService.double(for: measurement.soundPeak)
        case .voltage:
            guard let value = measurementService.double(for: measurement.voltage),
                  value != 0 else { return nil }
            return value
        case .rssi:
            return measurement.rssi.map(Double.init)
        case .accelerationX:
            return measurement.acceleration?.x.converted(to: .gravity).value
        case .accelerationY:
            return measurement.acceleration?.y.converted(to: .gravity).value
        case .accelerationZ:
            return measurement.acceleration?.z.converted(to: .gravity).value
        case .measurementSequenceNumber:
            return measurement.measurementSequenceNumber.map(Double.init)
        default:
            return nil
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func alertBounds(
        for variant: MeasurementDisplayVariant,
        sensor: AnyRuuviTagSensor?
    ) -> (lower: Double?, upper: Double?) {
        guard
            let sensor,
            let alertType = variant.type.toAlertType(),
            alertService.isOn(type: alertType, for: sensor)
        else {
            return (nil, nil)
        }

        switch measurementType(for: variant) {
        case .temperature:
            let unit = variant.resolvedTemperatureUnit(
                default: settings.temperatureUnit.unitTemperature
            )
            let upper = alertService.upperCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map { $0.converted(to: unit).value }
            let lower = alertService.lowerCelsius(for: sensor)
                .flatMap { Temperature($0, unit: .celsius) }
                .map { $0.converted(to: unit).value }
            return (lower, upper)
        case .humidity:
            guard variant.resolvedHumidityUnit(default: settings.humidityUnit) == .percent else {
                return (nil, nil)
            }
            let upper = alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 }
            let lower = alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 }
            return (lower, upper)
        case .pressure:
            let unit = variant.resolvedPressureUnit(default: settings.pressureUnit)
            let upper = alertService.upperPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { $0.converted(to: unit).value }
            let lower = alertService.lowerPressure(for: sensor)
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { $0.converted(to: unit).value }
            return (lower, upper)
        case .aqi:
            return (
                alertService.lowerAQI(for: sensor),
                alertService.upperAQI(for: sensor)
            )
        case .co2:
            return (
                alertService.lowerCarbonDioxide(for: sensor),
                alertService.upperCarbonDioxide(for: sensor)
            )
        case .pm10:
            return (
                alertService.lowerPM1(for: sensor),
                alertService.upperPM1(for: sensor)
            )
        case .pm25:
            return (
                alertService.lowerPM25(for: sensor),
                alertService.upperPM25(for: sensor)
            )
        case .pm40:
            return (
                alertService.lowerPM4(for: sensor),
                alertService.upperPM4(for: sensor)
            )
        case .pm100:
            return (
                alertService.lowerPM10(for: sensor),
                alertService.upperPM10(for: sensor)
            )
        case .voc:
            return (
                alertService.lowerVOC(for: sensor),
                alertService.upperVOC(for: sensor)
            )
        case .nox:
            return (
                alertService.lowerNOX(for: sensor),
                alertService.upperNOX(for: sensor)
            )
        case .luminosity:
            return (
                alertService.lowerLuminosity(for: sensor),
                alertService.upperLuminosity(for: sensor)
            )
        case .soundInstant:
            return (
                alertService.lowerSoundInstant(for: sensor),
                alertService.upperSoundInstant(for: sensor)
            )
        case .soundAverage:
            return (
                alertService.lowerSoundAverage(for: sensor),
                alertService.upperSoundAverage(for: sensor)
            )
        case .soundPeak:
            return (
                alertService.lowerSoundPeak(for: sensor),
                alertService.upperSoundPeak(for: sensor)
            )
        case .rssi:
            return (
                alertService.lowerSignal(for: sensor),
                alertService.upperSignal(for: sensor)
            )
        default:
            return (nil, nil)
        }
    }

    private func measurementType(
        for variant: MeasurementDisplayVariant
    ) -> MeasurementType {
        if variant.type.isSameCase(as: .humidity) {
            return .humidity
        }
        return variant.type
    }

    private func humidityTemperature(
        from measurement: RuuviMeasurement,
        sensorSettings: SensorSettings?,
        appliesOffset: Bool
    ) -> Temperature? {
        if appliesOffset {
            return measurement.temperature?.plus(sensorSettings: sensorSettings)
        } else {
            return measurement.temperature
        }
    }
}
