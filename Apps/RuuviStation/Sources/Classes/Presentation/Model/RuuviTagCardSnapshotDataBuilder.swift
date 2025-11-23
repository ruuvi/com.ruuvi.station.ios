// swiftlint:disable file_length

import UIKit
import RuuviOntology
import RuuviLocal
import RuuviLocalization
import Humidity
import RuuviService
import BTKit

// MARK: - Measurement Result
struct MeasurementResult {
    init(
        value: String,
        unit: String,
        isProminent: Bool,
        showSubscript: Bool,
        tintColor: UIColor? = nil,
        qualityState: MeasurementQualityState? = nil
    ) {
        self.value = value
        self.unit = unit
        self.isProminent = isProminent
        self.showSubscript = showSubscript
        self.tintColor = tintColor
        self.qualityState = qualityState
    }

    let value: String
    let unit: String
    let isProminent: Bool
    let showSubscript: Bool
    let tintColor: UIColor?
    let qualityState: MeasurementQualityState?

    func toIndicatorData(
        variant: MeasurementDisplayVariant
    ) -> RuuviTagCardSnapshotIndicatorData {
        return RuuviTagCardSnapshotIndicatorData(
            variant: variant,
            value: value,
            unit: unit,
            isProminent: isProminent,
            showSubscript: showSubscript,
            tintColor: tintColor,
            qualityState: qualityState
        )
    }
}

// MARK: - Measurement Variant Formatting Helpers
private enum MeasurementVariantFormatter {
    static func temperature(
        _ temperature: Temperature,
        measurementService: RuuviServiceMeasurement,
        variant: MeasurementDisplayVariant
    ) -> (value: String, unit: String) {
        if let overrideUnit = variant.temperatureUnit {
            let converted = temperature.converted(to: overrideUnit.unitTemperature)
            let value = measurementService.stringWithoutSign(temperature: converted.value)
            return (value, overrideUnit.symbol)
        } else {
            let value = measurementService.stringWithoutSign(for: temperature)
            return (value, measurementService.units.temperatureUnit.symbol)
        }
    }

    static func humidity(
        _ humidity: Humidity,
        temperature: Temperature,
        measurementService: RuuviServiceMeasurement,
        variant: MeasurementDisplayVariant
    ) -> (value: String, unit: String)? {
        let base = Humidity(
            value: humidity.value,
            unit: .relative(
                temperature: temperature
            )
        )
        let resolvedUnit = variant.humidityUnit ?? measurementService.units.humidityUnit
        switch resolvedUnit {
        case .percent:
            let percentValue = base.value * 100
            let value = measurementService.stringWithoutSign(humidity: percentValue)
            return (value, resolvedUnit.symbol)
        case .gm3:
            let absoluteValue = base.converted(to: .absolute).value
            let value = measurementService.stringWithoutSign(humidity: absoluteValue)
            return (value, resolvedUnit.symbol)
        case .dew:
            guard let dewPoint = try? base.dewPoint(temperature: temperature) else {
                return nil
            }
            let targetUnit = variant.temperatureUnit?.unitTemperature ?? measurementService.units.temperatureUnit
            let converted = dewPoint.converted(to: targetUnit)
            let value = measurementService.stringWithoutSign(temperature: converted.value)
            let unit = variant.temperatureUnit?.symbol ?? targetUnit.symbol
            return (value, unit)
        }
    }

    static func pressure(
        _ pressure: Pressure,
        measurementService: RuuviServiceMeasurement,
        variant: MeasurementDisplayVariant
    ) -> (value: String, unit: String) {
        let targetUnit = variant.pressureUnit ?? measurementService.units.pressureUnit
        let convertedValue = targetUnit.convertedValue(from: pressure)
        let value: String
        if targetUnit == .newtonsPerMetersSquared {
            value = String(Int(round(convertedValue)))
        } else {
            value = measurementService.stringWithoutSign(pressure: convertedValue)
        }
        return (value, targetUnit.ruuviSymbol)
    }
}

// MARK: - Measurement Extractor Protocol
protocol MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult?
}

// MARK: - Concrete Measurement Extractors
struct TemperatureMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let temperature = record.temperature,
              let measurementService = measurementService else { return nil }

        let formatted = MeasurementVariantFormatter.temperature(
            temperature,
            measurementService: measurementService,
            variant: variant
        )
        let firmware = RuuviDataFormat.dataFormat(from: record.version)
        let isProminent = firmware == .e1 || firmware == .v6

        return MeasurementResult(
            value: formatted.value,
            unit: formatted.unit,
            isProminent: isProminent,
            showSubscript: true,
            tintColor: nil
        )
    }
}

struct HumidityMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let humidity = record.humidity,
              let temperature = record.temperature,
              let measurementService = measurementService,
              let formatted = MeasurementVariantFormatter.humidity(
                humidity,
                temperature: temperature,
                measurementService: measurementService,
                variant: variant
              ) else { return nil }

        return MeasurementResult(
            value: formatted.value,
            unit: formatted.unit,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct PressureMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let pressure = record.pressure,
              let measurementService = measurementService else { return nil }

        let formatted = MeasurementVariantFormatter.pressure(
            pressure,
            measurementService: measurementService,
            variant: variant
        )

        return MeasurementResult(
            value: formatted.value,
            unit: formatted.unit,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct MovementMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let movement = record.movementCounter else { return nil }

        return MeasurementResult(
            value: "\(movement)",
            unit: RuuviLocalization.movements,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct AQIMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let (currentAirQIndex, maximumAirQIndex, state) = measurementService?.aqi(
            for: record.co2,
            pm25: record.pm25
        ) else { return nil }

        return MeasurementResult(
            value: "\(currentAirQIndex.stringValue)/\(maximumAirQIndex.stringValue)",
            unit: RuuviLocalization.airQuality,
            isProminent: true,
            showSubscript: true,
            tintColor: state.color,
            qualityState: state
        )
    }
}

// MARK: - Air Quality Measurement Extractors
struct CO2MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let co2 = record.co2,
              let (_, state) = measurementService?.co2(for: co2),
              let co2Value = measurementService?.co2String(for: co2) else {
            return nil
        }

        return MeasurementResult(
            value: co2Value,
            unit: RuuviLocalization.unitCo2,
            isProminent: false,
            showSubscript: false,
            tintColor: state.color,
            qualityState: state
        )
    }
}

struct PM25MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let pm25 = record.pm25,
              let (_, state) = measurementService?.pm25(for: pm25),
              let pm25Value = measurementService?.pm25String(for: pm25) else {
            return nil
        }

        return MeasurementResult(
            value: pm25Value,
            unit: RuuviLocalization.unitPm25,
            isProminent: false,
            showSubscript: false,
            tintColor: state.color,
            qualityState: state
        )
    }
}

struct PM1MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let pm1 = record.pm1,
              let pm1Value = measurementService?.pm10String(for: pm1) else { return nil }

        return MeasurementResult(
            value: pm1Value,
            unit: RuuviLocalization.unitPm10,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct PM40MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let pm4 = record.pm4,
              let pm4Value = measurementService?.pm40String(for: pm4) else { return nil }

        return MeasurementResult(
            value: pm4Value,
            unit: RuuviLocalization.unitPm40,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct PM10MeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let pm10 = record.pm10,
              let pm10Value = measurementService?.pm10String(for: pm10) else { return nil }

        return MeasurementResult(
            value: pm10Value,
            unit: RuuviLocalization.unitPm10,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct NOXMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let nox = record.nox,
              let noxValue = measurementService?.noxString(for: nox) else { return nil }

        return MeasurementResult(
            value: noxValue,
            unit: RuuviLocalization.unitNox,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct VOCMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let voc = record.voc,
              let vocValue = measurementService?.vocString(for: voc) else { return nil }

        return MeasurementResult(
            value: vocValue,
            unit: RuuviLocalization.unitVoc,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct LuminosityMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let luminosity = record.luminance,
              let luminosityValue = measurementService?.luminosityString(
                for: luminosity
              ) else { return nil }

        return MeasurementResult(
            value: luminosityValue,
            unit: RuuviLocalization.unitLuminosity,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct SoundMeasurementExtractor: MeasurementExtractor {
    enum Source {
        case instant
        case average
        case peak
    }

    private let source: Source

    init(source: Source = .instant) {
        self.source = source
    }

    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        let rawValue: Double?
        switch source {
        case .instant:
            rawValue = record.dbaInstant
        case .average:
            rawValue = record.dbaAvg
        case .peak:
            rawValue = record.dbaPeak
        }

        guard let sound = rawValue,
              let soundValue = measurementService?.soundString(
                for: sound
              ) else { return nil }

        return MeasurementResult(
            value: soundValue,
            unit: RuuviLocalization.unitSound,
            isProminent: false,
            showSubscript: false,
            tintColor: nil
        )
    }
}

struct VoltageMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let voltage = record.voltage,
              let value = measurementService?.string(for: voltage)else {
            return nil
        }

        return MeasurementResult(
            value: value,
            unit: RuuviLocalization.v,
            isProminent: false,
            showSubscript: false
        )
    }
}

struct TxPowerMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let txPower = record.txPower else { return nil }

        return MeasurementResult(
            value: "\(txPower)",
            unit: RuuviLocalization.dBm,
            isProminent: false,
            showSubscript: false
        )
    }
}

struct RSSIMeasurementExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let rssi = record.rssi else { return nil }

        return MeasurementResult(
            value: "\(rssi)",
            unit: RuuviLocalization.dBm,
            isProminent: false,
            showSubscript: false
        )
    }
}

struct AccelerationAxisMeasurementExtractor: MeasurementExtractor {
    enum Axis {
        case x
        case y
        case z
    }

    let axis: Axis

    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let acceleration = record.acceleration else { return nil }

        let measurement: AccelerationMeasurement
        switch axis {
        case .x: measurement = acceleration.x
        case .y: measurement = acceleration.y
        case .z: measurement = acceleration.z
        }

        guard let value = measurementService?.string(for: measurement.value) else {
            return nil
        }

        return MeasurementResult(
            value: value,
            unit: RuuviLocalization.g,
            isProminent: false,
            showSubscript: false
        )
    }
}

struct MeasurementSequenceExtractor: MeasurementExtractor {
    func extract(
        from record: RuuviTagSensorRecord,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        variant: MeasurementDisplayVariant,
        snapshot: RuuviTagCardSnapshot
    ) -> MeasurementResult? {
        guard let sequence = record.measurementSequenceNumber else { return nil }

        return MeasurementResult(
            value: "\(sequence)",
            unit: "",
            isProminent: false,
            showSubscript: false
        )
    }
}

// MARK: - Measurement Extractor Factory
struct MeasurementExtractorFactory {
    private static let extractors: [MeasurementType: MeasurementExtractor] = [
        .temperature: TemperatureMeasurementExtractor(),
        .humidity: HumidityMeasurementExtractor(),
        .pressure: PressureMeasurementExtractor(),
        .movementCounter: MovementMeasurementExtractor(),
        .aqi: AQIMeasurementExtractor(),
        .co2: CO2MeasurementExtractor(),
        .pm10: PM1MeasurementExtractor(),
        .pm25: PM25MeasurementExtractor(),
        .pm40: PM40MeasurementExtractor(),
        .pm100: PM10MeasurementExtractor(),
        .nox: NOXMeasurementExtractor(),
        .voc: VOCMeasurementExtractor(),
        .luminosity: LuminosityMeasurementExtractor(),
        .soundInstant: SoundMeasurementExtractor(source: .instant),
        .soundAverage: SoundMeasurementExtractor(source: .average),
        .soundPeak: SoundMeasurementExtractor(source: .peak),
        .voltage: VoltageMeasurementExtractor(),
        .txPower: TxPowerMeasurementExtractor(),
        .rssi: RSSIMeasurementExtractor(),
        .accelerationX: AccelerationAxisMeasurementExtractor(axis: .x),
        .accelerationY: AccelerationAxisMeasurementExtractor(axis: .y),
        .accelerationZ: AccelerationAxisMeasurementExtractor(axis: .z),
        .measurementSequenceNumber: MeasurementSequenceExtractor(),
    ]

    static func extractor(for type: MeasurementType) -> MeasurementExtractor? {
        return extractors[type]
    }
}

// MARK: - Indicator Data Manager
struct IndicatorDataManager {
    static func validateIndicators(
        _ indicators: [RuuviTagCardSnapshotIndicatorData]
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        return indicators.filter { indicator in
            guard !indicator.value.isEmpty else { return false }
            if MeasurementType.hideUnit(for: indicator.type) {
                return true
            }
            return !indicator.unit.isEmpty
        }
    }

    static func sortIndicatorsByPriority(
        _ indicators: [RuuviTagCardSnapshotIndicatorData],
        orderedVariants: [MeasurementDisplayVariant]
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        guard !orderedVariants.isEmpty else {
            return indicators
        }

        return indicators.sorted { first, second in
            let i0 = orderedVariants.firstIndex { $0 == first.variant } ?? .max
            let i1 = orderedVariants.firstIndex { $0 == second.variant } ?? .max
            return i0 < i1
        }
    }

    static func createGridConfiguration(
        indicators: [RuuviTagCardSnapshotIndicatorData],
        orderedVariants: [MeasurementDisplayVariant]
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        guard !indicators.isEmpty else { return nil }

        let validIndicators = validateIndicators(indicators)
        let sortedIndicators = sortIndicatorsByPriority(validIndicators, orderedVariants: orderedVariants)

        let adjustedIndicators: [RuuviTagCardSnapshotIndicatorData] =
            sortedIndicators.enumerated().map { index, indicator in
            RuuviTagCardSnapshotIndicatorData(
                variant: indicator.variant,
                value: indicator.value,
                unit: indicator.unit,
                isProminent: indicator.isProminent || index == 0,
                showSubscript: indicator.showSubscript,
                tintColor: indicator.tintColor,
                qualityState: indicator.qualityState
            )
        }

        return RuuviTagCardSnapshotIndicatorGridConfiguration(indicators: adjustedIndicators)
    }

}

// MARK: - Main RuuviTagCardSnapshot Data Builder
struct RuuviTagCardSnapshotDataBuilder {

    // MARK: - Main Factory Method
    static func createIndicatorGrid(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        snapshot: RuuviTagCardSnapshot
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        let displayProfile = RuuviTagDataService.measurementDisplayProfile(for: sensor)
        let indicators = createIndicators(
            from: record,
            sensor: sensor,
            measurementService: measurementService,
            flags: flags,
            snapshot: snapshot,
            displayProfile: displayProfile
        )

        return IndicatorDataManager.createGridConfiguration(
            indicators: indicators,
            orderedVariants: displayProfile.orderedVisibleVariants(for: .indicator)
        )
    }

    // MARK: - Indicator Creation
    // swiftlint:disable:next function_parameter_count
    private static func createIndicators(
        from record: RuuviTagSensorRecord,
        sensor: RuuviTagSensor,
        measurementService: RuuviServiceMeasurement?,
        flags: RuuviLocalFlags,
        snapshot: RuuviTagCardSnapshot,
        displayProfile: MeasurementDisplayProfile
    ) -> [RuuviTagCardSnapshotIndicatorData] {
        let measurementEntries = displayProfile.entries(for: .indicator)

        var indicators: [RuuviTagCardSnapshotIndicatorData] = []

        for entry in measurementEntries {
            let variant = entry.variant
            let type = variant.type
            if type == .voltage && !snapshot.capabilities.showBatteryStatus {
                continue
            }

            guard let extractor = MeasurementExtractorFactory.extractor(for: type),
                  let result = extractor.extract(
                    from: record,
                    measurementService: measurementService,
                    flags: flags,
                    variant: variant,
                    snapshot: snapshot
                  ) else {
                continue
            }

            indicators.append(result.toIndicatorData(variant: variant))
        }

        return indicators
    }
}

// swiftlint:enable file_length
