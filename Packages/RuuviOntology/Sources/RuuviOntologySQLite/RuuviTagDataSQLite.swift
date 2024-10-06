import Foundation
import GRDB
import Humidity

public struct RuuviTagDataSQLite: RuuviTagSensorRecord {
    public var luid: LocalIdentifier?
    public var date: Date
    public var source: RuuviTagSensorRecordSource
    public var macId: MACIdentifier?
    public var rssi: Int?
    public var version: Int
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
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
    }
}

public extension RuuviTagDataSQLite {
    static let idColumn = Column("id")
    static let ruuviTagIdColumn = Column("ruuviTagId")
    static let luidColumn = Column("luid")
    static let dateColumn = Column("date")
    static let sourceColumn = Column("source")
    static let macColumn = Column("mac")
    static let rssiColumn = Column("rssi")
    static let versionColumn = Column("version")
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

extension RuuviTagDataSQLite: Equatable {
    public static func == (lhs: RuuviTagDataSQLite, rhs: RuuviTagDataSQLite) -> Bool {
        lhs.id == rhs.id
    }
}

extension RuuviTagDataSQLite: FetchableRecord {
    public init(row: Row) {
        if let luidValue = String.fromDatabaseValue(row[RuuviTagDataSQLite.luidColumn]) {
            luid = LocalIdentifierStruct(value: luidValue)
        } else if let luidValue = String.fromDatabaseValue(row[RuuviTagDataSQLite.ruuviTagIdColumn]) {
            luid = LocalIdentifierStruct(value: luidValue)
        }
        date = row[RuuviTagDataSQLite.dateColumn]
        if let sourceString = String.fromDatabaseValue(row[RuuviTagDataSQLite.sourceColumn]) {
            source = RuuviTagSensorRecordSource(rawValue: sourceString) ?? .unknown
        } else {
            source = .unknown
        }
        if let macIdValue = String.fromDatabaseValue(row[RuuviTagDataSQLite.macColumn]) {
            macId = MACIdentifierStruct(value: macIdValue)
        }
        rssi = row[RuuviTagDataSQLite.rssiColumn]
        version = row[RuuviTagDataSQLite.versionColumn] ?? 5
        if let celsius = Double.fromDatabaseValue(row[RuuviTagDataSQLite.celsiusColumn]) {
            temperature = Temperature(value: celsius, unit: .celsius)
            if let relativeHumidity
                = Double.fromDatabaseValue(row[RuuviTagDataSQLite.relativeHumidityInPercentColumn]),
                let temperature {
                humidity = Humidity(
                    value: relativeHumidity,
                    unit: .relative(temperature: temperature)
                )
            }
        }
        if let hectopascals = Double.fromDatabaseValue(row[RuuviTagDataSQLite.hectopascalsColumn]) {
            pressure = Pressure(value: hectopascals, unit: .hectopascals)
        }
        if let accelerationX = Double.fromDatabaseValue(row[RuuviTagDataSQLite.accelerationXColumn]),
           let accelerationY = Double.fromDatabaseValue(row[RuuviTagDataSQLite.accelerationYColumn]),
           let accelerationZ = Double.fromDatabaseValue(row[RuuviTagDataSQLite.accelerationZColumn]) {
            acceleration = Acceleration(
                x: AccelerationMeasurement(value: accelerationX, unit: .metersPerSecondSquared),
                y: AccelerationMeasurement(value: accelerationY, unit: .metersPerSecondSquared),
                z: AccelerationMeasurement(value: accelerationZ, unit: .metersPerSecondSquared)
            )
        }
        if let volts = Double.fromDatabaseValue(row[RuuviTagDataSQLite.voltsColumn]) {
            voltage = Voltage(value: volts, unit: .volts)
        }
        movementCounter = row[RuuviTagDataSQLite.movementCounterColumn]
        measurementSequenceNumber = row[RuuviTagDataSQLite.measurementSequenceNumberColumn]
        txPower = row[RuuviTagDataSQLite.txPowerColumn]
        temperatureOffset = row[RuuviTagDataSQLite.temperatureOffsetColumn]
        humidityOffset = row[RuuviTagDataSQLite.humidityOffsetColumn]
        pressureOffset = row[RuuviTagDataSQLite.pressureOffsetColumn]
    }
}

extension RuuviTagDataSQLite: PersistableRecord {
    public static var databaseTableName: String {
        "ruuvi_tag_sensor_records"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviTagDataSQLite.idColumn] = id
        container[RuuviTagDataSQLite.luidColumn] = luid?.value
        container[RuuviTagDataSQLite.macColumn] = macId?.value
        container[RuuviTagDataSQLite.ruuviTagIdColumn] = macId?.value ?? luid?.value ?? ""
        container[RuuviTagDataSQLite.dateColumn] = date
        container[RuuviTagDataSQLite.sourceColumn] = source.rawValue
        container[RuuviTagDataSQLite.rssiColumn] = rssi
        container[RuuviTagDataSQLite.versionColumn] = version
        container[RuuviTagDataSQLite.celsiusColumn] = temperature?.converted(to: .celsius).value
        container[RuuviTagDataSQLite.relativeHumidityInPercentColumn] = humidity?.value
        container[RuuviTagDataSQLite.hectopascalsColumn] = pressure?.converted(to: .hectopascals).value
        container[RuuviTagDataSQLite.accelerationXColumn] = acceleration?.x.converted(to: .metersPerSecondSquared).value
        container[RuuviTagDataSQLite.accelerationYColumn] = acceleration?.y.converted(to: .metersPerSecondSquared).value
        container[RuuviTagDataSQLite.accelerationZColumn] = acceleration?.z.converted(to: .metersPerSecondSquared).value
        container[RuuviTagDataSQLite.voltsColumn] = voltage?.converted(to: .volts).value
        container[RuuviTagDataSQLite.movementCounterColumn] = movementCounter
        container[RuuviTagDataSQLite.measurementSequenceNumberColumn] = measurementSequenceNumber
        container[RuuviTagDataSQLite.txPowerColumn] = txPower
        container[RuuviTagDataSQLite.temperatureOffsetColumn] = temperatureOffset
        container[RuuviTagDataSQLite.humidityOffsetColumn] = humidityOffset
        container[RuuviTagDataSQLite.pressureOffsetColumn] = pressureOffset
    }
}

public extension RuuviTagDataSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviTagDataSQLite.databaseTableName, body: { table in
            table.column(RuuviTagDataSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(RuuviTagDataSQLite.ruuviTagIdColumn.name, .text).notNull()
            table.column(RuuviTagDataSQLite.luidColumn.name, .text)
            table.column(RuuviTagDataSQLite.dateColumn.name, .datetime).notNull()
            table.column(RuuviTagDataSQLite.sourceColumn.name, .text).notNull()
            table.column(RuuviTagDataSQLite.macColumn.name, .text)
            table.column(RuuviTagDataSQLite.rssiColumn.name, .integer)
            table.column(RuuviTagDataSQLite.versionColumn.name, .integer).notNull()
            table.column(RuuviTagDataSQLite.celsiusColumn.name, .double)
            table.column(RuuviTagDataSQLite.relativeHumidityInPercentColumn.name, .double)
            table.column(RuuviTagDataSQLite.hectopascalsColumn.name, .double)
            table.column(RuuviTagDataSQLite.accelerationXColumn.name, .double)
            table.column(RuuviTagDataSQLite.accelerationYColumn.name, .double)
            table.column(RuuviTagDataSQLite.accelerationZColumn.name, .double)
            table.column(RuuviTagDataSQLite.voltsColumn.name, .double)
            table.column(RuuviTagDataSQLite.movementCounterColumn.name, .integer)
            table.column(RuuviTagDataSQLite.measurementSequenceNumberColumn.name, .integer)
            table.column(RuuviTagDataSQLite.txPowerColumn.name, .integer)
            table.column(RuuviTagDataSQLite.temperatureOffsetColumn.name, .double).notNull()
            table.column(RuuviTagDataSQLite.humidityOffsetColumn.name, .double).notNull()
            table.column(RuuviTagDataSQLite.pressureOffsetColumn.name, .double).notNull()
        })
    }
}
