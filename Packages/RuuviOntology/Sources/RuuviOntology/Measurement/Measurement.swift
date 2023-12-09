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

public extension Temperature {
    init?(_ value: Double?, unit: UnitTemperature = .celsius) {
        if let temperature = value {
            self = Temperature(value: temperature, unit: unit)
        } else {
            return nil
        }
    }

    func plus(sensorSettings: SensorSettings?) -> Temperature? {
        Temperature(
            value + (sensorSettings?.temperatureOffset ?? 0), unit: unit
        )
    }

    func minus(value: Double?) -> Temperature? {
        Temperature(
            self.value - (value ?? 0), unit: unit
        )
    }
}

public extension Pressure {
    init?(_ value: Double?, unit: UnitPressure = .hectopascals) {
        if let pressure = value {
            self = Pressure(value: pressure, unit: unit)
        } else {
            return nil
        }
    }

    func plus(sensorSettings: SensorSettings?) -> Pressure? {
        Pressure(
            value + (sensorSettings?.pressureOffset ?? 0), unit: unit
        )
    }

    func minus(value: Double?) -> Pressure? {
        Pressure(
            self.value - (value ?? 0), unit: unit
        )
    }
}

public extension Humidity {
    init?(relative value: Double?, temperature: Temperature?) {
        if let relativeHumidity = value,
           let temperature {
            self = Humidity(value: relativeHumidity, unit: .relative(temperature: temperature))
        } else {
            return nil
        }
    }

    func plus(sensorSettings: SensorSettings?) -> Humidity? {
        Humidity(value: value + (sensorSettings?.humidityOffset ?? 0), unit: unit)
    }

    func minus(value: Double?) -> Humidity? {
        Humidity(value: self.value - (value ?? 0), unit: unit)
    }

    static var zeroAbsolute: Humidity {
        Humidity(value: 0, unit: .absolute)
    }
}
