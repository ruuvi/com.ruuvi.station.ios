import Foundation

public enum MeasurementDisplayDefaults {
    public static let baseMeasurementPriority: [MeasurementType] = [
        .aqi,
        .co2,
        .pm25,
        .voc,
        .nox,
        .temperature,
        .humidity,
        .pressure,
        .luminosity,
        .movementCounter,
        .soundInstant,
        .soundAverage,
        .soundPeak,
        .pm10,
        .pm40,
        .pm100,
        .voltage,
        .accelerationX,
        .accelerationY,
        .accelerationZ,
        .measurementSequenceNumber,
        .rssi,
    ]

    public static let airSupportedMeasurements: [MeasurementType] = [
        .aqi,
        .co2,
        .pm10,
        .pm25,
        .pm40,
        .pm100,
        .voc,
        .nox,
        .temperature,
        .humidity,
        .pressure,
        .luminosity,
        .measurementSequenceNumber,
        .soundInstant,
        .soundPeak,
        .soundAverage,
        .rssi,
    ]

    public static let tagSupportedMeasurements: [MeasurementType] = [
        .temperature,
        .humidity,
        .pressure,
        .movementCounter,
        .measurementSequenceNumber,
        .voltage,
        .accelerationX,
        .accelerationY,
        .accelerationZ,
        .rssi,
    ]

    public static func orderedMeasurements(for supportedTypes: [MeasurementType]) -> [MeasurementType] {
        var ordered = baseMeasurementPriority.filter { baseType in
            supportedTypes.contains(baseType)
        }

        let remaining = supportedTypes.filter { candidate in
            !ordered.contains(candidate)
        }

        ordered.append(contentsOf: remaining)
        return ordered
    }

    public static func measurementOrder(for format: RuuviDataFormat) -> [MeasurementType] {
        switch format {
        case .e1, .v6:
            return airMeasurementOrder
        default:
            return tagMeasurementOrder
        }
    }

    public static var airMeasurementOrder: [MeasurementType] {
        orderedMeasurements(for: airSupportedMeasurements)
    }

    public static var tagMeasurementOrder: [MeasurementType] {
        orderedMeasurements(for: tagSupportedMeasurements)
    }
}
