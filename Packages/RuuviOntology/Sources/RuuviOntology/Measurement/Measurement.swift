import Foundation
import Humidity

public typealias Temperature = Measurement<UnitTemperature>
public typealias Pressure = Measurement<UnitPressure>
public typealias Humidity = Measurement<UnitHumidity>
public typealias Voltage = Measurement<UnitElectricPotentialDifference>
public typealias AccelerationMeasurement = Measurement<UnitAcceleration>

public struct Acceleration {
    public let x: AccelerationMeasurement
    public let y: AccelerationMeasurement
    public let z: AccelerationMeasurement

    public init(
        x: AccelerationMeasurement,
        y: AccelerationMeasurement,
        z: AccelerationMeasurement
    ) {
        self.x = x
        self.y = y
        self.z = z
    }
}

extension Temperature {
    public init?(_ value: Double?, unit: UnitTemperature = .celsius) {
        if let temperature = value {
            self = Temperature(value: temperature, unit: unit)
        } else {
            return nil
        }
    }

    public func plus(sensorSettings: SensorSettings?) -> Temperature? {
        return Temperature(
            self.value + (sensorSettings?.temperatureOffset ?? 0), unit: self.unit
        )
    }

    public func minus(value: Double?) -> Temperature? {
        return Temperature(
            self.value - (value ?? 0), unit: self.unit
        )
    }
}

extension Pressure {
    public init?(_ value: Double?, unit: UnitPressure = .hectopascals) {
        if let pressure = value {
            self = Pressure(value: pressure, unit: unit)
        } else {
            return nil
        }
    }

    public func plus(sensorSettings: SensorSettings?) -> Pressure? {
        return Pressure(
            self.value + (sensorSettings?.pressureOffset ?? 0), unit: self.unit
        )
    }

    public func minus(value: Double?) -> Pressure? {
        return Pressure(
            self.value - (value ?? 0), unit: self.unit
        )
    }
}

extension Humidity {
    public init?(relative value: Double?, temperature: Temperature?) {
        if let relativeHumidity = value,
            let temperature = temperature {
            self = Humidity(value: relativeHumidity, unit: .relative(temperature: temperature))
        } else {
            return nil
        }
    }

    public func plus(sensorSettings: SensorSettings?) -> Humidity? {
        return Humidity(value: self.value + (sensorSettings?.humidityOffset ?? 0), unit: self.unit)
    }

    public func minus(value: Double?) -> Humidity? {
        return Humidity(value: self.value - (value ?? 0), unit: self.unit)
    }

    public static var zeroAbsolute: Humidity {
        return Humidity(value: 0, unit: .absolute)
    }
}
