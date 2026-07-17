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
        sensor: AnyRuuviTagSensor?,
        alertConfig: RuuviTagCardSnapshotAlertConfig? = nil
    ) -> (lower: Double?, upper: Double?) {
        guard
            let sensor,
            let alertType = variant.toAlertType(),
            alertConfig?.isActive ?? alertService.isOn(type: alertType, for: sensor)
        else {
            return (nil, nil)
        }
        switch measurementType(for: variant) {
        case .temperature:
            let unit = variant.resolvedTemperatureUnit(
                default: settings.temperatureUnit.unitTemperature
            )
            let upper = (alertConfig?.upperBound ?? alertService.upperCelsius(for: sensor))
                .flatMap { Temperature($0, unit: .celsius) }
                .map { $0.converted(to: unit).value }
            let lower = (alertConfig?.lowerBound ?? alertService.lowerCelsius(for: sensor))
                .flatMap { Temperature($0, unit: .celsius) }
                .map { $0.converted(to: unit).value }
            let alertRange = temperatureAlertRange(for: sensor, unit: unit)
            return visibleAlertBounds(
                lower: lower,
                upper: upper,
                minimum: alertRange.lower,
                maximum: alertRange.upper
            )
        case .humidity:
            guard variant.resolvedHumidityUnit(default: settings.humidityUnit) == .percent else {
                return (nil, nil)
            }
            let upper = alertConfig?.upperBound ??
                alertService.upperRelativeHumidity(for: sensor).map { $0 * 100 }
            let lower = alertConfig?.lowerBound ??
                alertService.lowerRelativeHumidity(for: sensor).map { $0 * 100 }
            return visibleAlertBounds(
                lower: lower,
                upper: upper,
                minimum: RuuviAlertConstants.RelativeHumidity.lowerBound,
                maximum: RuuviAlertConstants.RelativeHumidity.upperBound
            )
        case .pressure:
            let unit = variant.resolvedPressureUnit(default: settings.pressureUnit)
            let upper = (alertConfig?.upperBound ?? alertService.upperPressure(for: sensor))
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { $0.converted(to: unit).value }
            let lower = (alertConfig?.lowerBound ?? alertService.lowerPressure(for: sensor))
                .flatMap { Pressure($0, unit: .hectopascals) }
                .map { $0.converted(to: unit).value }
            return visibleAlertBounds(
                lower: lower,
                upper: upper,
                minimum: pressureValue(RuuviAlertConstants.Pressure.lowerBound, unit: unit),
                maximum: pressureValue(RuuviAlertConstants.Pressure.upperBound, unit: unit)
            )
        case .aqi:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerAQI(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperAQI(for: sensor),
                range: RuuviAlertConstants.AQI.lowerBound...RuuviAlertConstants.AQI.upperBound
            )
        case .co2:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerCarbonDioxide(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperCarbonDioxide(for: sensor),
                range: carbonDioxideAlertRange(for: sensor)
            )
        case .pm10:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerPM1(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperPM1(for: sensor),
                range: particulateMatterAlertRange(for: sensor)
            )
        case .pm25:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerPM25(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperPM25(for: sensor),
                range: particulateMatterAlertRange(for: sensor)
            )
        case .pm40:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerPM4(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperPM4(for: sensor),
                range: particulateMatterAlertRange(for: sensor)
            )
        case .pm100:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerPM10(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperPM10(for: sensor),
                range: particulateMatterAlertRange(for: sensor)
            )
        case .voc:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerVOC(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperVOC(for: sensor),
                range: RuuviAlertConstants.VOC.lowerBound...RuuviAlertConstants.VOC.upperBound
            )
        case .nox:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerNOX(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperNOX(for: sensor),
                range: RuuviAlertConstants.NOX.lowerBound...RuuviAlertConstants.NOX.upperBound
            )
        case .luminosity:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerLuminosity(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperLuminosity(for: sensor),
                range: RuuviAlertConstants.Luminosity.lowerBound...RuuviAlertConstants.Luminosity.upperBound
            )
        case .soundInstant:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerSoundInstant(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperSoundInstant(for: sensor),
                range: RuuviAlertConstants.Sound.lowerBound...RuuviAlertConstants.Sound.upperBound
            )
        case .soundAverage:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerSoundAverage(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperSoundAverage(for: sensor),
                range: RuuviAlertConstants.Sound.lowerBound...RuuviAlertConstants.Sound.upperBound
            )
        case .soundPeak:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerSoundPeak(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperSoundPeak(for: sensor),
                range: RuuviAlertConstants.Sound.lowerBound...RuuviAlertConstants.Sound.upperBound
            )
        case .rssi:
            return visibleAlertBounds(
                lower: alertConfig?.lowerBound ?? alertService.lowerSignal(for: sensor),
                upper: alertConfig?.upperBound ?? alertService.upperSignal(for: sensor),
                range: RuuviAlertConstants.Signal.lowerBound...RuuviAlertConstants.Signal.upperBound
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

    private func visibleAlertBounds(
        lower: Double?,
        upper: Double?,
        range: ClosedRange<Double>
    ) -> (lower: Double?, upper: Double?) {
        visibleAlertBounds(
            lower: lower,
            upper: upper,
            minimum: range.lowerBound,
            maximum: range.upperBound
        )
    }

    private func visibleAlertBounds(
        lower: Double?,
        upper: Double?,
        minimum: Double,
        maximum: Double
    ) -> (lower: Double?, upper: Double?) {
        let visibleLower = lower.flatMap {
            isSameAlertBoundary($0, minimum) ? nil : $0
        }
        let visibleUpper = upper.flatMap {
            isSameAlertBoundary($0, maximum) ? nil : $0
        }
        return (visibleLower, visibleUpper)
    }

    private func isSameAlertBoundary(_ value: Double, _ boundary: Double) -> Bool {
        abs(value - boundary) <= 0.000_001
    }

    private func pressureValue(_ value: Double, unit: UnitPressure) -> Double {
        Pressure(value, unit: .hectopascals)?.converted(to: unit).value ?? value
    }

    private func temperatureAlertRange(
        for sensor: AnyRuuviTagSensor,
        unit: UnitTemperature
    ) -> (lower: Double, upper: Double) {
        let usesCustomRange = settings.showCustomTempAlertBound(for: sensor.id)
        let lower = usesCustomRange
            ? RuuviAlertConstants.Temperature.customLowerBound
            : RuuviAlertConstants.Temperature.lowerBound
        let upper = usesCustomRange
            ? RuuviAlertConstants.Temperature.customUpperBound
            : RuuviAlertConstants.Temperature.upperBound

        return (
            Temperature(value: lower, unit: .celsius).converted(to: unit).value,
            Temperature(value: upper, unit: .celsius).converted(to: unit).value
        )
    }

    private func carbonDioxideAlertRange(for sensor: AnyRuuviTagSensor) -> ClosedRange<Double> {
        if settings.showCustomCO2AlertBound(for: sensor.id) {
            return ClosedRange(uncheckedBounds: (
                lower: RuuviAlertConstants.CarbonDioxide.customLowerBound,
                upper: RuuviAlertConstants.CarbonDioxide.customUpperBound
            ))
        }
        return ClosedRange(uncheckedBounds: (
            lower: RuuviAlertConstants.CarbonDioxide.lowerBound,
            upper: RuuviAlertConstants.CarbonDioxide.upperBound
        ))
    }

    private func particulateMatterAlertRange(for sensor: AnyRuuviTagSensor) -> ClosedRange<Double> {
        if settings.showCustomPMAlertBound(for: sensor.id) {
            return ClosedRange(uncheckedBounds: (
                lower: RuuviAlertConstants.ParticulateMatter.customLowerBound,
                upper: RuuviAlertConstants.ParticulateMatter.customUpperBound
            ))
        }
        return ClosedRange(uncheckedBounds: (
            lower: RuuviAlertConstants.ParticulateMatter.lowerBound,
            upper: RuuviAlertConstants.ParticulateMatter.upperBound
        ))
    }
}
