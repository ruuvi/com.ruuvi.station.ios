import Foundation
import Humidity

typealias Temperature = Measurement<UnitTemperature>
typealias Pressure = Measurement<UnitPressure>
typealias Humidity = Measurement<UnitHumidity>
typealias Voltage = Measurement<UnitElectricPotentialDifference>
typealias AccelerationMeasurement = Measurement<UnitAcceleration>

struct Acceleration {
    let x: AccelerationMeasurement
    let y: AccelerationMeasurement
    let z: AccelerationMeasurement
}

extension Temperature {
    init?(_ value: Double?, unit: UnitTemperature = .celsius) {
        if let temperature = value {
            self = Temperature(value: temperature, unit: unit)
        } else {
            return nil
        }
    }

    func withSensorSettings(sensorSettings: SensorSettings?) -> Temperature? {
        return Temperature(
            self.value + (sensorSettings?.temperatureOffset ?? 0), unit: self.unit
        )
    }
}

extension Pressure {
    init?(_ value: Double?, unit: UnitPressure = .hectopascals) {
        if let pressure = value {
            self = Pressure(value: pressure, unit: unit)
        } else {
            return nil
        }
    }

    func withSensorSettings(sensorSettings: SensorSettings?) -> Pressure? {
        return Pressure(
            self.value + (sensorSettings?.pressureOffset ?? 0), unit: self.unit
        )
    }
}

extension Humidity {
    init?(relative value: Double?, temperature: Temperature?) {
        if let relativeHumidity = value,
            let temperature = temperature {
            self = Humidity(value: relativeHumidity, unit: .relative(temperature: temperature))
        } else {
            return nil
        }
    }

    func withSensorSettings(sensorSettings: SensorSettings?) -> Humidity? {
        return Humidity(value: self.value + (sensorSettings?.humidityOffset ?? 0), unit: self.unit)
    }

    static var zeroAbsolute: Humidity {
        return Humidity(value: 0, unit: .absolute)
    }
}
