import Foundation
import GRDB
import Humidity

public struct RuuviTagLatestDataSQLite: RuuviTagSensorRecord {
    public var id: String
    public var luid: LocalIdentifier?
    public var date: Date
    public var source: RuuviTagSensorRecordSource
    public var macId: MACIdentifier?
    public var rssi: Int?
    public var temperature: Temperature?
    public var humidity: Humidity?
    public var pressure: Pressure?
    public var acceleration: Acceleration?
    public var voltage: Voltage?
    public var movementCounter: Int?
    public var measurementSequenceNumber: Int?
    public var txPower: Int?
    public var temperatureOffset: Double
    public var humidityOffset: Double
    public var pressureOffset: Double

    public init(
        id: String,
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
        self.id = id
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

public extension RuuviTagLatestDataSQLite {
    static let idColumn = Column("id")
    static let ruuviTagIdColumn = Column("ruuviTagId")
    static let luidColumn = Column("luid")
    static let dateColumn = Column("date")
    static let sourceColumn = Column("source")
    static let macColumn = Column("mac")
    static let rssiColumn = Column("rssi")
    static let celsiusColumn = Column("celsius")
    static let relativeHumidityInPercentColumn = Column("relativeHumidityInPercent")
    static let hectopascalsColumn = Column("hectopascals")
    static let accelerationXColumn = Column("accelerationX")
    static let accelerationYColumn = Column("accelerationY")
    static let accelerationZColumn = Column("accelerationZ")
    static let voltsColumn = Column("volts")
    static let movementCounterColumn = Column("movementCounter")
    static let measurementSequenceNumberColumn = Column("measurementSequenceNumber")
    static let txPowerColumn = Column("txPower")
    static let temperatureOffsetColumn = Column("temperatureOffset")
    static let humidityOffsetColumn = Column("humidityOffset")
    static let pressureOffsetColumn = Column("pressureOffset")
}

extension RuuviTagLatestDataSQLite: Equatable {
    public static func == (lhs: RuuviTagLatestDataSQLite, rhs: RuuviTagLatestDataSQLite) -> Bool {
        lhs.id == rhs.id
    }
}

extension RuuviTagLatestDataSQLite: FetchableRecord {
    public init(row: Row) {
        id = row[RuuviTagLatestDataSQLite.idColumn]
        if let luidValue = String.fromDatabaseValue(row[RuuviTagLatestDataSQLite.luidColumn]) {
            luid = LocalIdentifierStruct(value: luidValue)
        } else if let luidValue = String.fromDatabaseValue(row[RuuviTagLatestDataSQLite.ruuviTagIdColumn]) {
            luid = LocalIdentifierStruct(value: luidValue)
        }
        date = row[RuuviTagLatestDataSQLite.dateColumn]
        if let sourceString = String.fromDatabaseValue(row[RuuviTagLatestDataSQLite.sourceColumn]) {
            source = RuuviTagSensorRecordSource(rawValue: sourceString) ?? .unknown
        } else {
            source = .unknown
        }
        if let macIdValue = String.fromDatabaseValue(row[RuuviTagLatestDataSQLite.macColumn]) {
            macId = MACIdentifierStruct(value: macIdValue)
        }
        rssi = row[RuuviTagLatestDataSQLite.rssiColumn]
        if let celsius = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.celsiusColumn]) {
            temperature = Temperature(value: celsius, unit: .celsius)
            if let relativeHumidity
                = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.relativeHumidityInPercentColumn]),
                let temperature {
                humidity = Humidity(
                    value: relativeHumidity,
                    unit: .relative(temperature: temperature)
                )
            }
        }
        if let hectopascals = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.hectopascalsColumn]) {
            pressure = Pressure(value: hectopascals, unit: .hectopascals)
        }
        if let accelerationX = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.accelerationXColumn]),
           let accelerationY = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.accelerationYColumn]),
           let accelerationZ = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.accelerationZColumn]) {
            acceleration = Acceleration(
                x: AccelerationMeasurement(value: accelerationX, unit: .metersPerSecondSquared),
                y: AccelerationMeasurement(value: accelerationY, unit: .metersPerSecondSquared),
                z: AccelerationMeasurement(value: accelerationZ, unit: .metersPerSecondSquared)
            )
        }
        if let volts = Double.fromDatabaseValue(row[RuuviTagLatestDataSQLite.voltsColumn]) {
            voltage = Voltage(value: volts, unit: .volts)
        }
        movementCounter = row[RuuviTagLatestDataSQLite.movementCounterColumn]
        measurementSequenceNumber = row[RuuviTagLatestDataSQLite.measurementSequenceNumberColumn]
        txPower = row[RuuviTagLatestDataSQLite.txPowerColumn]
        temperatureOffset = row[RuuviTagLatestDataSQLite.temperatureOffsetColumn]
        humidityOffset = row[RuuviTagLatestDataSQLite.humidityOffsetColumn]
        pressureOffset = row[RuuviTagLatestDataSQLite.pressureOffsetColumn]
    }
}

extension RuuviTagLatestDataSQLite: PersistableRecord {
    public static var databaseTableName: String {
        "ruuvi_tag_sensor_record_latest"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviTagLatestDataSQLite.idColumn] = id
        container[RuuviTagLatestDataSQLite.luidColumn] = luid?.value
        container[RuuviTagLatestDataSQLite.macColumn] = macId?.value
        container[RuuviTagLatestDataSQLite.ruuviTagIdColumn] = macId?.value ?? luid?.value ?? ""
        container[RuuviTagLatestDataSQLite.dateColumn] = date
        container[RuuviTagLatestDataSQLite.sourceColumn] = source.rawValue
        container[RuuviTagLatestDataSQLite.rssiColumn] = rssi
        container[RuuviTagLatestDataSQLite.celsiusColumn] = temperature?.converted(to: .celsius).value
        container[RuuviTagLatestDataSQLite.relativeHumidityInPercentColumn] = humidity?.value
        container[RuuviTagLatestDataSQLite.hectopascalsColumn] = pressure?.converted(to: .hectopascals).value
        container[RuuviTagLatestDataSQLite.accelerationXColumn] = acceleration?.x
            .converted(to: .metersPerSecondSquared).value
        container[RuuviTagLatestDataSQLite.accelerationYColumn] = acceleration?.y
            .converted(to: .metersPerSecondSquared).value
        container[RuuviTagLatestDataSQLite.accelerationZColumn] = acceleration?.z
            .converted(to: .metersPerSecondSquared).value
        container[RuuviTagLatestDataSQLite.voltsColumn] = voltage?.converted(to: .volts).value
        container[RuuviTagLatestDataSQLite.movementCounterColumn] = movementCounter
        container[RuuviTagLatestDataSQLite.measurementSequenceNumberColumn] = measurementSequenceNumber
        container[RuuviTagLatestDataSQLite.txPowerColumn] = txPower
        container[RuuviTagLatestDataSQLite.temperatureOffsetColumn] = temperatureOffset
        container[RuuviTagLatestDataSQLite.humidityOffsetColumn] = humidityOffset
        container[RuuviTagLatestDataSQLite.pressureOffsetColumn] = pressureOffset
    }
}

public extension RuuviTagLatestDataSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviTagLatestDataSQLite.databaseTableName, body: { table in
            table.column(RuuviTagLatestDataSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(RuuviTagLatestDataSQLite.ruuviTagIdColumn.name, .text).notNull()
            table.column(RuuviTagLatestDataSQLite.luidColumn.name, .text)
            table.column(RuuviTagLatestDataSQLite.dateColumn.name, .datetime).notNull()
            table.column(RuuviTagLatestDataSQLite.sourceColumn.name, .text).notNull()
            table.column(RuuviTagLatestDataSQLite.macColumn.name, .text)
            table.column(RuuviTagLatestDataSQLite.rssiColumn.name, .integer)
            table.column(RuuviTagLatestDataSQLite.celsiusColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.relativeHumidityInPercentColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.hectopascalsColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.accelerationXColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.accelerationYColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.accelerationZColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.voltsColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.movementCounterColumn.name, .integer)
            table.column(RuuviTagLatestDataSQLite.measurementSequenceNumberColumn.name, .integer)
            table.column(RuuviTagLatestDataSQLite.txPowerColumn.name, .integer)
            table.column(RuuviTagLatestDataSQLite.temperatureOffsetColumn.name, .double).notNull()
            table.column(RuuviTagLatestDataSQLite.humidityOffsetColumn.name, .double).notNull()
            table.column(RuuviTagLatestDataSQLite.pressureOffsetColumn.name, .double).notNull()
        })
    }
}
