import Foundation

public extension RuuviTagSensorRecord {
    var measurement: RuuviMeasurement {
        RuuviMeasurement(
            luid: luid,
            macId: macId,
            measurementSequenceNumber: measurementSequenceNumber,
            date: date,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            co2: co2,
            pm1: pm1,
            pm25: pm25,
            pm4: pm4,
            pm10: pm10,
            voc: voc,
            nox: nox,
            luminosity: luminance,
            soundInstant: dbaInstant,
            soundAvg: dbaAvg,
            soundPeak: dbaPeak,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            txPower: txPower
        )
    }
}

public extension RuuviTagSensorRecord {

    // swiftlint:disable:next cyclomatic_complexity
    func hasMeasurement(for type: MeasurementType) -> Bool {
        switch type {
        case .temperature:
            return temperature != nil
        case .humidity:
            return humidity != nil
        case .pressure:
            return pressure != nil
        case .aqi:
            return co2 != nil || pm25 != nil
        case .co2:
            return co2 != nil
        case .pm10:
            return pm1 != nil
        case .pm25:
            return pm25 != nil
        case .pm40:
            return pm4 != nil
        case .pm100:
            return pm10 != nil
        case .voc:
            return voc != nil
        case .nox:
            return nox != nil
        case .luminosity:
            return luminance != nil
        case .soundInstant:
            return dbaInstant != nil
        case .voltage:
            return voltage != nil
        case .rssi:
            return rssi != nil
        case .accelerationX, .accelerationY, .accelerationZ:
            return acceleration != nil
        default:
            return false
        }
    }
}
