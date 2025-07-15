import Foundation
import Humidity

public struct RuuviMeasurement {
    public var id: String {
        if let macId,
           !macId.value.isEmpty {
            macId.value
        } else if let luid {
            luid.value
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
    // E1/V6
    public var co2: Double?
    public var pm25: Double?
    public var pm10: Double?
    public var voc: Double?
    public var nox: Double?
    public var luminosity: Double?
    public var sound: Double? // Avg
    // Backword compatibility for the users using versions < 0.7.7
    public var temperatureOffset: Double?
    public var humidityOffset: Double?
    public var pressureOffset: Double?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        measurementSequenceNumber: Int?,
        date: Date,
        rssi: Int?,
        temperature: Temperature?,
        humidity: Humidity?,
        pressure: Pressure?,
        co2: Double?,
        pm25: Double?,
        pm10: Double?,
        voc: Double?,
        nox: Double?,
        luminosity: Double?,
        sound: Double?,
        acceleration: Acceleration?,
        voltage: Voltage?,
        movementCounter: Int?,
        txPower: Int?,
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?
    ) {
        self.luid = luid
        self.macId = macId
        self.measurementSequenceNumber = measurementSequenceNumber
        self.date = date
        self.rssi = rssi
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.co2 = co2
        self.pm25 = pm25
        self.pm10 = pm10
        self.voc = voc
        self.nox = nox
        self.luminosity = luminosity
        self.sound = sound
        self.acceleration = acceleration
        self.voltage = voltage
        self.movementCounter = movementCounter
        self.txPower = txPower
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
    }
}
