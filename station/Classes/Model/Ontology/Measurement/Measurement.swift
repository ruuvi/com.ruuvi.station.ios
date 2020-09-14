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
}

extension Pressure {
    init?(_ value: Double?, unit: UnitPressure = .hectopascals) {
        if let pressure = value {
            self = Pressure(value: pressure, unit: unit)
        } else {
            return nil
        }
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

    /// Humidity with relative offset
    /// - Parameters:
    ///   - value: offset, 0...1.0
    ///   - temperature: temperature
    /// - Returns: humidity value
    func withRelativeOffset(by offset: Double, withTemperature temperature: Temperature) -> Humidity {
        var relative = self.converted(to: .relative(temperature: temperature)).value
        var offset = offset
        if relative > 1.0 {
            relative /= 100
        }
        if offset > 1.0 {
            offset /= 100
        }
        let offseted = min(relative + offset, 1.0)
        return Humidity(value: offseted, unit: .relative(temperature: temperature))
    }
}
