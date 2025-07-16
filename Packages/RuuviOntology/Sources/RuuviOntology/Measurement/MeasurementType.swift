import Foundation

public enum MeasurementType: String {
    case rssi
    case temperature
    case humidity
    case pressure
    // v3 & v5
    case acceleration
    case voltage
    // v5
    case movementCounter
    case txPower
    // E1/V6
    case aqi
    case co2
    case pm25
    case pm10
    case nox
    case voc
    case luminosity
    case soundInstant
}
