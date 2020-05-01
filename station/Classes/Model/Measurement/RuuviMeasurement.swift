import Foundation
import Humidity

typealias Temperature = Measurement<UnitTemperature>
typealias Pressure = Measurement<UnitPressure>
typealias Voltage = Measurement<UnitElectricPotentialDifference>
typealias AccelerationMeasurement = Measurement<UnitAcceleration>

struct Acceleration {
    let x: AccelerationMeasurement
    let y: AccelerationMeasurement
    let z: AccelerationMeasurement
}

struct RuuviMeasurement {
    let tagUuid: String
    let measurementSequenceNumber: Int?
    let date: Date
    let rssi: Int?
    let temperature: Temperature?
    let humidity: Humidity?
    let pressure: Pressure?
    // v3 & v5
    let acceleration: Acceleration?
    let voltage: Voltage?
    // v5
    let movementCounter: Int?
    let txPower: Int?
}
