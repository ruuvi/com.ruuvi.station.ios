// swiftlint:disable file_length
import Foundation
import Humidity

public enum RuuviTagSensorRecordSource: String {
    case unknown
    case advertisement
    case bgAdvertisement
    case log
    case heartbeat
    case ruuviNetwork
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
    // E0/F0
    var pm1: Double? { get }
    var pm2_5: Double? { get }
    var pm4: Double? { get }
    var pm10: Double? { get }
    var co2: Double? { get }
    var voc: Double? { get }
    var nox: Double? { get }
    var luminance: Double? { get }
    var dbaAvg: Double? { get }
    var dbaPeak: Double? { get }

    // offset correction
    var temperatureOffset: Double { get }
    var humidityOffset: Double { get }
    var pressureOffset: Double { get }

    // Firmware version
    var version: Int { get }
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
            version: version,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            pm1: pm1,
            pm2_5: pm2_5,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminance,
            dbaAvg: dbaAvg,
            dbaPeak: dbaPeak,
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
            version: version,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            pm1: pm1,
            pm2_5: pm2_5,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminance,
            dbaAvg: dbaAvg,
            dbaPeak: dbaPeak,
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
            version: version,
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            acceleration: acceleration,
            voltage: voltage,
            movementCounter: movementCounter,
            measurementSequenceNumber: measurementSequenceNumber,
            txPower: txPower,
            pm1: pm1,
            pm2_5: pm2_5,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminance,
            dbaAvg: dbaAvg,
            dbaPeak: dbaPeak,
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
            version: version,
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
            pm1: pm1,
            pm2_5: pm2_5,
            pm4: pm4,
            pm10: pm10,
            co2: co2,
            voc: voc,
            nox: nox,
            luminance: luminance,
            dbaAvg: dbaAvg,
            dbaPeak: dbaPeak,
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
    public var version: Int
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
    // E0/F0
    public var pm1: Double?
    public var pm2_5: Double?
    public var pm4: Double?
    public var pm10: Double?
    public var co2: Double?
    public var voc: Double?
    public var nox: Double?
    public var luminance: Double?
    public var dbaAvg: Double?
    public var dbaPeak: Double?

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
        version: Int,
        temperature: Temperature?,
        humidity: Humidity?,
        pressure: Pressure?,
        acceleration: Acceleration?,
        voltage: Voltage?,
        movementCounter: Int?,
        measurementSequenceNumber: Int?,
        txPower: Int?,
        pm1: Double?,
        pm2_5: Double?,
        pm4: Double?,
        pm10: Double?,
        co2: Double?,
        voc: Double?,
        nox: Double?,
        luminance: Double?,
        dbaAvg: Double?,
        dbaPeak: Double?,
        temperatureOffset: Double,
        humidityOffset: Double,
        pressureOffset: Double
    ) {
        self.luid = luid
        self.date = date
        self.source = source
        self.macId = macId
        self.rssi = rssi
        self.version = version
        self.temperature = temperature
        self.humidity = humidity
        self.pressure = pressure
        self.acceleration = acceleration
        self.voltage = voltage
        self.movementCounter = movementCounter
        self.measurementSequenceNumber = measurementSequenceNumber
        self.txPower = txPower
        self.pm1 = pm1
        self.pm2_5 = pm2_5
        self.pm4 = pm4
        self.pm10 = pm10
        self.co2 = co2
        self.voc = voc
        self.nox = nox
        self.luminance = luminance
        self.dbaAvg = dbaAvg
        self.dbaPeak = dbaPeak
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

    public var version: Int {
        object.version
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

    public var pm1: Double? {
        object.pm1
    }

    public var pm2_5: Double? {
        object.pm2_5
    }

    public var pm4: Double? {
        object.pm4
    }

    public var pm10: Double? {
        object.pm10
    }

    public var co2: Double? {
        object.co2
    }

    public var voc: Double? {
        object.voc
    }

    public var nox: Double? {
        object.nox
    }

    public var luminance: Double? {
        object.luminance
    }

    public var dbaAvg: Double? {
        object.dbaAvg
    }

    public var dbaPeak: Double? {
        object.dbaPeak
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
// swiftlint:enable file_length
