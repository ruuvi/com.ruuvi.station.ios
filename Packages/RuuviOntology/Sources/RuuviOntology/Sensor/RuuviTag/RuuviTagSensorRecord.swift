import Foundation
import Humidity

public enum RuuviTagSensorRecordSource: String {
    case unknown
    case advertisement
    case log
    case heartbeat
    case ruuviNetwork
    case weatherProvider
}

public protocol RuuviTagSensorRecord: PhysicalSensor {
    var luid: LocalIdentifier? { get }
    var date: Date { get }
    var source: RuuviTagSensorRecordSource { get }
    var macId: MACIdentifier? { get }
    var rssi: Int? { get }
    var temperature: Temperature? { get }
    var humidity: Humidity? { get }
    var pressure: Pressure? { get }
    // v3 & v5
    var acceleration: Acceleration? { get }
    var voltage: Voltage? { get }
    // v5
    var movementCounter: Int? { get }
    var measurementSequenceNumber: Int? { get }
    var txPower: Int? { get }

    // offset correction
    var temperatureOffset: Double { get }
    var humidityOffset: Double { get }
    var pressureOffset: Double { get }
}

public extension RuuviTagSensorRecord {
    var id: String {
        if let macId,
           !macId.value.isEmpty {
            macId.value + "\(date.timeIntervalSince1970)"
        } else if let luid {
            luid.value + "\(date.timeIntervalSince1970)"
        } else {
            fatalError()
        }
    }

    var uuid: String {
        if let macId,
           !macId.value.isEmpty {
            macId.value
        } else if let luid {
            luid.value
        } else {
            fatalError()
        }
    }

    var any: AnyRuuviTagSensorRecord {
        AnyRuuviTagSensorRecord(object: self)
    }

    func with(macId: MACIdentifier) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }

    func with(luid: LocalIdentifier) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }
}

public extension RuuviTagSensorRecord {
    func with(source: RuuviTagSensorRecordSource) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset
        )
    }

    func with(sensorSettings: SensorSettings?) -> RuuviTagSensorRecord {
        RuuviTagSensorRecordStruct(
            luid: luid,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature?
                .minus(value: temperatureOffset)?
                .plus(sensorSettings: sensorSettings),
            humidity: humidity?
                .minus(value: humidityOffset)?
                .plus(sensorSettings: sensorSettings),
            pressure: pressure?
                .minus(value: pressureOffset)?
                .plus(sensorSettings: sensorSettings),
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            temperatureOffset: sensorSettings?.temperatureOffset ?? 0.0,
            humidityOffset: sensorSettings?.humidityOffset ?? 0.0,
            pressureOffset: sensorSettings?.pressureOffset ?? 0.0
        )
    }
}

public struct RuuviTagSensorRecordStruct: RuuviTagSensorRecord {
    public var luid: LocalIdentifier?
    public var date: Date
    public var source: RuuviTagSensorRecordSource
    public var macId: MACIdentifier?
    public var rssi: Int?
    public var temperature: Temperature?
    public var humidity: Humidity?
    public var pressure: Pressure?
    // v3 & v5
    public var acceleration: Acceleration?
    public var voltage: Voltage?
    // v5
    public var movementCounter: Int?
    public var measurementSequenceNumber: Int?
    public var txPower: Int?

    // offset correction
    public var temperatureOffset: Double
    public var humidityOffset: Double
    public var pressureOffset: Double

    public init(
        luid: LocalIdentifier?,
        date: Date,
        source: RuuviTagSensorRecordSource,
        macId: MACIdentifier?,
        rssi: Int?,
        temperature: Temperature?,
        humidity: Humidity?,
        pressure: Pressure?,
        acceleration: Acceleration?,
        voltage: Voltage?,
        movementCounter: Int?,
        measurementSequenceNumber: Int?,
        txPower: Int?,
        temperatureOffset: Double,
        humidityOffset: Double,
        pressureOffset: Double
    ) {
        self.luid = luid
        self.date = date
        self.source = source
        self.macId = macId
        self.rssi = rssi
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.acceleration = acceleration
        self.voltage = voltage
        self.movementCounter = movementCounter
        self.measurementSequenceNumber = measurementSequenceNumber
        self.txPower = txPower
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
    }
}

public struct AnyRuuviTagSensorRecord: RuuviTagSensorRecord, Equatable, Hashable {
    var object: RuuviTagSensorRecord

    public init(object: RuuviTagSensorRecord) {
        self.object = object
    }

    public var luid: LocalIdentifier? {
        object.luid
    }

    public var date: Date {
        object.date
    }

    public var source: RuuviTagSensorRecordSource {
        object.source
    }

    public var macId: MACIdentifier? {
        object.macId
    }

    public var rssi: Int? {
        object.rssi
    }

    public var temperature: Temperature? {
        object.temperature
    }

    public var humidity: Humidity? {
        object.humidity
    }

    public var pressure: Pressure? {
        object.pressure
    }

    public var acceleration: Acceleration? {
        object.acceleration
    }

    public var voltage: Voltage? {
        object.voltage
    }

    public var movementCounter: Int? {
        object.movementCounter
    }

    public var measurementSequenceNumber: Int? {
        object.measurementSequenceNumber
    }

    public var txPower: Int? {
        object.txPower
    }

    public var temperatureOffset: Double {
        object.temperatureOffset
    }

    public var humidityOffset: Double {
        object.humidityOffset
    }

    public var pressureOffset: Double {
        object.pressureOffset
    }

    public static func == (lhs: AnyRuuviTagSensorRecord, rhs: AnyRuuviTagSensorRecord) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
