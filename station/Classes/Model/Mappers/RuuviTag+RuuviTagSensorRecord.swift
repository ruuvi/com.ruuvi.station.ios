import Foundation
import BTKit
import Humidity

extension RuuviTag: RuuviTagSensorRecord {
    var ruuviTagId: String {
        return mac ?? uuid
    }

    var macId: MACIdentifier? {
        return mac?.mac
    }

    var date: Date {
        return Date()
    }

    var temperature: Temperature? {
        return Temperature(self.celsius)
    }

    var humidity: Humidity? {
        guard let rH = self.relativeHumidity else {
            return nil
        }
        return Humidity(relative: rH / 100.0, temperature: temperature)
    }

    var pressure: Pressure? {
        guard let hectopascals = self.hectopascals else {
            return nil
        }
        return Pressure(value: hectopascals, unit: .hectopascals)
    }

    var acceleration: Acceleration? {
        guard let accelerationX = self.accelerationX,
            let accelerationY = self.accelerationY,
            let accelerationZ = self.accelerationZ else {
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

    var voltage: Voltage? {
        guard let voltage = self.volts else { return nil }
        return Voltage(value: voltage, unit: .volts)
    }

}
