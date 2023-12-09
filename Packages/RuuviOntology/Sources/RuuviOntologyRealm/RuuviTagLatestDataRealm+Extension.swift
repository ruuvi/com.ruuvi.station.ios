import Foundation
import Humidity
import RealmSwift
import RuuviOntology

public extension RuuviTagLatestDataRealm {
    var unitTemperature: Temperature? {
        guard let celsius = celsius.value else {
            return nil
        }
        return Temperature(value: celsius,
                           unit: .celsius)
    }

    var unitHumidity: Humidity? {
        guard let celsius = celsius.value,
              let relativeHumidity = humidity.value
        else {
            return nil
        }
        return Humidity(relative: relativeHumidity,
                        temperature: Temperature(value: celsius, unit: .celsius))
    }

    var unitPressure: Pressure? {
        guard let pressure = pressure.value else {
            return nil
        }
        return Pressure(value: pressure,
                        unit: .hectopascals)
    }

    var acceleration: Acceleration? {
        guard let accelerationX = accelerationX.value,
              let accelerationY = accelerationY.value,
              let accelerationZ = accelerationZ.value
        else {
            return nil
        }
        return Acceleration(x:
            AccelerationMeasurement(value: accelerationX,
                                    unit: .metersPerSecondSquared),
            y:
            AccelerationMeasurement(value: accelerationY,
                                    unit: .metersPerSecondSquared),
            z:
            AccelerationMeasurement(value: accelerationZ,
                                    unit: .metersPerSecondSquared))
    }

    var unitVoltage: Voltage? {
        guard let voltage = voltage.value else { return nil }
        return Voltage(value: voltage, unit: .volts)
    }

    var measurement: RuuviMeasurement {
        RuuviMeasurement(
            luid: ruuviTag?.luid,
            macId: ruuviTag?.macId,
            measurementSequenceNumber: measurementSequenceNumber.value,
            date: date,
            rssi: rssi.value,
            temperature: unitTemperature,
            humidity: unitHumidity,
            pressure: unitPressure,
            acceleration: acceleration,
            voltage: unitVoltage,
            movementCounter: movementCounter.value,
            txPower: txPower.value,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }
}
