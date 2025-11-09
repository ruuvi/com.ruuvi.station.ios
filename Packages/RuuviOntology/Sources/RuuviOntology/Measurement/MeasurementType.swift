import Foundation

public enum MeasurementType: Hashable {
    case rssi
    case temperature
    case humidity
    case pressure
    // v3 & v5
    case accelerationX
    case accelerationY
    case accelerationZ
    case voltage
    // v5
    case movementCounter
    case txPower
    case measurementSequenceNumber
    // E1/V6
    case aqi
    case co2
    case pm10
    case pm25
    case pm40
    case pm100
    case nox
    case voc
    case luminosity
    case soundInstant
    case soundPeak
    case soundAverage
}
