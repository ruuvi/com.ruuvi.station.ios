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
    public var pm1: Double?
    public var pm25: Double?
    public var pm4: Double?
    public var pm10: Double?
    public var co2: Double?
    public var voc: Double?
    public var nox: Double?
    public var luminance: Double?
    public var dbaInstant: Double?
    public var dbaAvg: Double?
    public var dbaPeak: Double?
    public var temperatureOffset: Double
    public var humidityOffset: Double
    public var pressureOffset: Double
    public var version: Int

    public init(
        id: String,
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
        pm25: Double?,
        pm4: Double?,
        pm10: Double?,
        co2: Double?,
        voc: Double?,
        nox: Double?,
        luminance: Double?,
        dbaInstant: Double?,
        dbaAvg: Double?,
        dbaPeak: Double?,
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
        self.pm25 = pm25
        self.pm4 = pm4
        self.pm10 = pm10
        self.co2 = co2
        self.voc = voc
        self.nox = nox
        self.luminance = luminance
        self.dbaInstant = dbaInstant
        self.dbaAvg = dbaAvg
        self.dbaPeak = dbaPeak
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
    static let pm1Column = Column("pm1")
    static let pm25Column = Column("pm2_5")
    static let pm4Column = Column("pm4")
    static let pm10Column = Column("pm10")
    static let co2Column = Column("co2")
    static let vocColumn = Column("voc")
    static let noxColumn = Column("nox")
    static let luminanceColumn = Column("luminance")
    static let dbaInstantColumn = Column("dbaInstant")
    static let dbaAvgColumn = Column("dbaAvg")
    static let dbaPeakColumn = Column("dbaPeak")
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

    // swiftlint:disable:next function_body_length
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
        version = row[RuuviTagLatestDataSQLite.versionColumn] ?? 5
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
        pm1 = row[RuuviTagLatestDataSQLite.pm1Column]
        pm25 = row[RuuviTagLatestDataSQLite.pm25Column]
        pm4 = row[RuuviTagLatestDataSQLite.pm4Column]
        pm10 = row[RuuviTagLatestDataSQLite.pm10Column]
        co2 = row[RuuviTagLatestDataSQLite.co2Column]
        voc = row[RuuviTagLatestDataSQLite.vocColumn]
        nox = row[RuuviTagLatestDataSQLite.noxColumn]
        luminance = row[RuuviTagLatestDataSQLite.luminanceColumn]
        dbaInstant = row[RuuviTagLatestDataSQLite.dbaInstantColumn]
        dbaAvg = row[RuuviTagLatestDataSQLite.dbaAvgColumn]
        dbaPeak = row[RuuviTagLatestDataSQLite.dbaPeakColumn]
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
        container[RuuviTagLatestDataSQLite.versionColumn] = version
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
        container[RuuviTagLatestDataSQLite.pm1Column] = pm1
        container[RuuviTagLatestDataSQLite.pm25Column] = pm25
        container[RuuviTagLatestDataSQLite.pm4Column] = pm4
        container[RuuviTagLatestDataSQLite.pm10Column] = pm10
        container[RuuviTagLatestDataSQLite.co2Column] = co2
        container[RuuviTagLatestDataSQLite.vocColumn] = voc
        container[RuuviTagLatestDataSQLite.noxColumn] = nox
        container[RuuviTagLatestDataSQLite.luminanceColumn] = luminance
        container[RuuviTagLatestDataSQLite.dbaInstantColumn] = dbaInstant
        container[RuuviTagLatestDataSQLite.dbaAvgColumn] = dbaAvg
        container[RuuviTagLatestDataSQLite.dbaPeakColumn] = dbaPeak
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
            table.column(RuuviTagLatestDataSQLite.versionColumn.name, .integer).notNull()
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
            table.column(RuuviTagLatestDataSQLite.pm1Column.name, .double)
            table.column(RuuviTagLatestDataSQLite.pm25Column.name, .double)
            table.column(RuuviTagLatestDataSQLite.pm4Column.name, .double)
            table.column(RuuviTagLatestDataSQLite.pm10Column.name, .double)
            table.column(RuuviTagLatestDataSQLite.co2Column.name, .double)
            table.column(RuuviTagLatestDataSQLite.vocColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.noxColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.luminanceColumn.name, .double)
            table
                .column(RuuviTagLatestDataSQLite.dbaInstantColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.dbaAvgColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.dbaPeakColumn.name, .double)
            table.column(RuuviTagLatestDataSQLite.temperatureOffsetColumn.name, .double).notNull()
            table.column(RuuviTagLatestDataSQLite.humidityOffsetColumn.name, .double).notNull()
            table.column(RuuviTagLatestDataSQLite.pressureOffsetColumn.name, .double).notNull()
        })
    }
}
