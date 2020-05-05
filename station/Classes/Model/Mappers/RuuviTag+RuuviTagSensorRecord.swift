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
        guard let celsius = self.celsius else { return nil }
        return Temperature(value: celsius, unit: .celsius)
    }

    var humidity: Humidity? {
        guard let celsius = self.celsius,
            let relativeHumidity = self.relativeHumidity else {
            return nil
        }
        return Humidity(c: celsius, rh: relativeHumidity / 100.0)
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
