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

public protocol RuuviTagSensorRecord {
    var ruuviTagId: LocalIdentifier? { get }
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

extension RuuviTagSensorRecord {
    public var id: String {
        if let macId = macId,
            !macId.value.isEmpty {
            return macId.value + "\(date.timeIntervalSince1970)"
        } else if let ruuviTagId = ruuviTagId {
            return ruuviTagId.value + "\(date.timeIntervalSince1970)"
        } else {
            fatalError()
        }
    }

    public var any: AnyRuuviTagSensorRecord {
        return AnyRuuviTagSensorRecord(object: self)
    }

    public func with(macId: MACIdentifier) -> RuuviTagSensorRecord {
        return RuuviTagSensorRecordStruct(
            ruuviTagId: ruuviTagId,
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

extension RuuviTagSensorRecord {
    public func with(source: RuuviTagSensorRecordSource) -> RuuviTagSensorRecord {
        return RuuviTagSensorRecordStruct(
            ruuviTagId: ruuviTagId,
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

    public func with(sensorSettings: SensorSettings?) -> RuuviTagSensorRecord {
        return RuuviTagSensorRecordStruct(
            ruuviTagId: ruuviTagId,
            date: date,
            source: source,
            macId: macId,
            rssi: rssi,
            temperature: temperature?.withSensorSettings(sensorSettings: sensorSettings),
            humidity: humidity?.withSensorSettings(sensorSettings: sensorSettings),
            pressure: pressure?.withSensorSettings(sensorSettings: sensorSettings),
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
    public var ruuviTagId: LocalIdentifier?
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
        ruuviTagId: LocalIdentifier?,
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
        self.ruuviTagId = ruuviTagId
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

    public var ruuviTagId: LocalIdentifier? {
        return object.ruuviTagId
    }

    public var date: Date {
        return object.date
    }

    public var source: RuuviTagSensorRecordSource {
        return object.source
    }

    public var macId: MACIdentifier? {
        return object.macId
    }

    public var rssi: Int? {
        return object.rssi
    }

    public var temperature: Temperature? {
        return object.temperature
    }

    public var humidity: Humidity? {
        return object.humidity
    }

    public var pressure: Pressure? {
        return object.pressure
    }

    public var acceleration: Acceleration? {
        return object.acceleration
    }

    public var voltage: Voltage? {
        return object.voltage
    }

    public var movementCounter: Int? {
        return object.movementCounter
    }

    public var measurementSequenceNumber: Int? {
        return object.measurementSequenceNumber
    }

    public var txPower: Int? {
        return object.txPower
    }

    public var temperatureOffset: Double {
        return object.temperatureOffset
    }

    public var humidityOffset: Double {
        return object.humidityOffset
    }

    public var pressureOffset: Double {
        return object.pressureOffset
    }

    public static func == (lhs: AnyRuuviTagSensorRecord, rhs: AnyRuuviTagSensorRecord) -> Bool {
        return lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
