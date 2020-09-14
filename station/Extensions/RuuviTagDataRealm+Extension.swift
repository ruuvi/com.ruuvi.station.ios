import Foundation
import Humidity

extension RuuviTagDataRealm {
    var unitTemperature: Temperature? {
        guard let celsius = self.celsius.value else {
            return nil
        }
        return Temperature(value: celsius,
                           unit: .celsius)
    }
    var unitHumidity: Humidity? {
        guard let celsius = self.celsius.value,
            let relativeHumidity = self.humidity.value else {
            return nil
        }
        return Humidity(relative: relativeHumidity,
                        temperature: Temperature(value: celsius, unit: .celsius))
    }
    var unitPressure: Pressure? {
        guard let pressure = self.pressure.value else {
            return nil
        }
        return Pressure(value: pressure,
                        unit: .hectopascals)
    }
    var acceleration: Acceleration? {
        guard let accelerationX = self.accelerationX.value,
            let accelerationY = self.accelerationY.value,
            let accelerationZ = self.accelerationZ.value else {
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
                                    unit: .metersPerSecondSquared)
        )
    }
    var unitVoltage: Voltage? {
        guard let voltage = self.voltage.value else { return nil }
        return Voltage(value: voltage, unit: .volts)
    }
    var measurement: RuuviMeasurement {
        return RuuviMeasurement(ruuviTagId: ruuviTag!.uuid,
                                measurementSequenceNumber: measurementSequenceNumber.value,
                                date: date,
                                rssi: rssi.value,
                                temperature: unitTemperature,
                                humidity: unitHumidity,
                                pressure: unitPressure,
                                acceleration: acceleration,
                                voltage: unitVoltage,
                                movementCounter: movementCounter.value,
                                txPower: txPower.value)
    }
}
