import Foundation

typealias Temperature = Measurement<UnitTemperature>
typealias Pressure = Measurement<UnitPressure>
typealias Voltage = Measurement<UnitElectricPotentialDifference>
typealias AccelerationMeasurement = Measurement<UnitAcceleration>

struct Acceleration {
    let x: AccelerationMeasurement
    let y: AccelerationMeasurement
    let z: AccelerationMeasurement
}
