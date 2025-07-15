import BTKit
import Foundation
import Humidity

extension RuuviTag: RuuviTagSensorRecord {
    public var luid: LocalIdentifier? {
        uuid.luid
    }

    public var macId: MACIdentifier? {
        mac?.mac
    }

    public var date: Date {
        Date()
    }

    public var source: RuuviTagSensorRecordSource {
        .unknown
    }

    public var temperature: Temperature? {
        Temperature(celsius)
    }

    public var humidity: Humidity? {
        guard let rH = relativeHumidity
        else {
            return nil
        }
        return Humidity(relative: rH / 100.0, temperature: temperature)
    }

    public var pressure: Pressure? {
        guard let hectopascals
        else {
            return nil
        }
        return Pressure(value: hectopascals, unit: .hectopascals)
    }

    public var acceleration: Acceleration? {
        guard let accelerationX,
              let accelerationY,
              let accelerationZ
        else {
            return nil
        }
        return Acceleration(
            x:
            AccelerationMeasurement(
                value: accelerationX,
                unit: .metersPerSecondSquared
            ),
            y:
            AccelerationMeasurement(
                value: accelerationY,
                unit: .metersPerSecondSquared
            ),
            z:
            AccelerationMeasurement(
                value: accelerationZ,
                unit: .metersPerSecondSquared
            )
        )
    }

    public var voltage: Voltage? {
        guard let voltage = volts else { return nil }
        return Voltage(value: voltage, unit: .volts)
    }

    public var pm1: Double? {
        pMatter1
    }

    public var pm25: Double? {
        pMatter25
    }

    public var pm4: Double? {
        pMatter4
    }

    public var pm10: Double? {
        pMatter10
    }

    public var co2: Double? {
        carbonDioxide
    }

    public var voc: Double? {
        volatileOrganicCompound
    }

    public var nox: Double? {
        nitrogenOxide
    }

    public var luminance: Double? {
        luminanceValue
    }

    public var dbaInstant: Double? {
        decibelInstant
    }

    public var dbaAvg: Double? {
        decibelAverage
    }

    public var dbaPeak: Double? {
        decibelPeak
    }

    public var temperatureOffset: Double { 0.0 }
    public var humidityOffset: Double { 0.0 }
    public var pressureOffset: Double { 0.0 }
}
