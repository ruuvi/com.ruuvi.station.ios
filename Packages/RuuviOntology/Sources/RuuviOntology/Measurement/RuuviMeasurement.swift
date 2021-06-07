import Foundation
import Humidity

public struct RuuviMeasurement {
    public var id: String {
        if let macId = macId,
            !macId.value.isEmpty {
            return macId.value
        } else if let luid = luid {
            return luid.value
        } else {
            fatalError()
        }
    }
    public var luid: LocalIdentifier?
    public var macId: MACIdentifier?
    public var measurementSequenceNumber: Int?
    public var date: Date
    public var rssi: Int?
    public var temperature: Temperature?
    public var humidity: Humidity?
    public var pressure: Pressure?
    // v3 & v5
    public var acceleration: Acceleration?
    public var voltage: Voltage?
    // v5
    public var movementCounter: Int?
    public var txPower: Int?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        measurementSequenceNumber: Int?,
        date: Date,
        rssi: Int?,
        temperature: Temperature?,
        humidity: Humidity?,
        pressure: Pressure?,
        acceleration: Acceleration?,
        voltage: Voltage?,
        movementCounter: Int?,
        txPower: Int?
    ) {
        self.luid = luid
        self.macId = macId
        self.measurementSequenceNumber = measurementSequenceNumber
        self.date = date
        self.rssi = rssi
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.acceleration = acceleration
        self.voltage = voltage
        self.movementCounter = movementCounter
        self.txPower = txPower
    }
}
