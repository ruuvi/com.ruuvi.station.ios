import Foundation
import BTKit
import Humidity
import RuuviOntology

extension RuuviTag: RuuviTagSensorRecord {
    public var luid: LocalIdentifier? {
        return uuid.luid
    }

    public var macId: MACIdentifier? {
        return mac?.mac
    }

    public var date: Date {
        return Date()
    }

    public var source: RuuviTagSensorRecordSource {
        return .unknown
    }

    public var temperature: Temperature? {
        return Temperature(self.celsius)
    }

    public var humidity: Humidity? {
        guard let rH = self.relativeHumidity else {
            return nil
        }
        return Humidity(relative: rH / 100.0, temperature: temperature)
    }

    public var pressure: Pressure? {
        guard let hectopascals = self.hectopascals else {
            return nil
        }
        return Pressure(value: hectopascals, unit: .hectopascals)
    }

    public var acceleration: Acceleration? {
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

    public var voltage: Voltage? {
        guard let voltage = self.volts else { return nil }
        return Voltage(value: voltage, unit: .volts)
    }

    public var temperatureOffset: Double { return 0.0 }
    public var humidityOffset: Double { return 0.0 }
    public var pressureOffset: Double { return 0.0 }
}
