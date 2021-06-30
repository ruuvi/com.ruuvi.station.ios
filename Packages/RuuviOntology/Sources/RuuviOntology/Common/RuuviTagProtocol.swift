import Foundation

public protocol RuuviTagProtocol {
    var uuid: String { get }
    var version: Int { get }
    var isConnected: Bool { get }
    var isConnectable: Bool { get }
    var accelerationX: Double? { get }
    var accelerationY: Double? { get }
    var accelerationZ: Double? { get }
    var celsius: Double? { get }
    var fahrenheit: Double? { get }
    var kelvin: Double? { get }
    var relativeHumidity: Double? { get }
    var hectopascals: Double? { get }
    var inHg: Double? { get }
    var mmHg: Double? { get }
    var measurementSequenceNumber: Int? { get }
    var movementCounter: Int? { get }
    var mac: String? { get }
    var source: RuuviTagSensorRecordSource { get }
    var rssi: Int? { get }
    var txPower: Int? { get }
    var volts: Double? { get }
}
