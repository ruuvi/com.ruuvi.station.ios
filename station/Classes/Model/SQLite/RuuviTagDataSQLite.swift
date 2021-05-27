import Foundation
import GRDB
import Humidity

struct RuuviTagDataSQLite: RuuviTagSensorRecord {
    var ruuviTagId: String
    var date: Date
    var source: RuuviTagSensorRecordSource
    var macId: MACIdentifier?
    var rssi: Int?
    var temperature: Temperature?
    var humidity: Humidity?
    var pressure: Pressure?
    var acceleration: Acceleration?
    var voltage: Voltage?
    var movementCounter: Int?
    var measurementSequenceNumber: Int?
    var txPower: Int?
    var temperatureOffset: Double
    var humidityOffset: Double
    var pressureOffset: Double
}

extension RuuviTagDataSQLite {
    static let idColumn = Column("id")
    static let ruuviTagIdColumn = Column("ruuviTagId")
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

extension RuuviTagDataSQLite: Equatable {
    static func == (lhs: RuuviTagDataSQLite, rhs: RuuviTagDataSQLite) -> Bool {
        return lhs.id == rhs.id
    }
}

extension RuuviTagDataSQLite: FetchableRecord {
    init(row: Row) {
        ruuviTagId = row[RuuviTagDataSQLite.ruuviTagIdColumn]
        date = row[RuuviTagDataSQLite.dateColumn]
        if let sourceString = String.fromDatabaseValue(row[RuuviTagDataSQLite.sourceColumn]) {
            source = RuuviTagSensorRecordSource(rawValue: sourceString) ?? .unknown
        } else {
            source = .unknown
        }
        macId = MACIdentifierStruct(value: row[RuuviTagDataSQLite.macColumn])
        rssi = row[RuuviTagDataSQLite.rssiColumn]
        if let celsius = Double.fromDatabaseValue(row[RuuviTagDataSQLite.celsiusColumn]) {
            temperature = Temperature(value: celsius, unit: .celsius)
            if let relativeHumidity
                = Double.fromDatabaseValue(row[RuuviTagDataSQLite.relativeHumidityInPercentColumn]),
                let temperature = temperature {
                humidity = Humidity(value: relativeHumidity,
                                    unit: .relative(temperature: temperature))
            }
        }
        if let hectopascals = Double.fromDatabaseValue(row[RuuviTagDataSQLite.hectopascalsColumn]) {
            pressure = Pressure(value: hectopascals, unit: .hectopascals)
        }
        if let accelerationX = Double.fromDatabaseValue(row[RuuviTagDataSQLite.accelerationXColumn]),
            let accelerationY = Double.fromDatabaseValue(row[RuuviTagDataSQLite.accelerationYColumn]),
            let accelerationZ = Double.fromDatabaseValue(row[RuuviTagDataSQLite.accelerationZColumn]) {
            acceleration = Acceleration(x: AccelerationMeasurement(value: accelerationX, unit: .metersPerSecondSquared),
                                        y: AccelerationMeasurement(value: accelerationY, unit: .metersPerSecondSquared),
                                        z: AccelerationMeasurement(value: accelerationZ, unit: .metersPerSecondSquared))
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
    static var databaseTableName: String {
        return "ruuvi_tag_sensor_records"
    }

    func encode(to container: inout PersistenceContainer) {
        container[RuuviTagDataSQLite.idColumn] = id
        container[RuuviTagDataSQLite.ruuviTagIdColumn] = ruuviTagId
        container[RuuviTagDataSQLite.dateColumn] = date
        container[RuuviTagDataSQLite.sourceColumn] = source.rawValue
        container[RuuviTagDataSQLite.macColumn] = macId?.value
        container[RuuviTagDataSQLite.rssiColumn] = rssi
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

extension RuuviTagDataSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviTagDataSQLite.databaseTableName, body: { table in
            table.column(RuuviTagDataSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(RuuviTagDataSQLite.ruuviTagIdColumn.name, .text).notNull()
            table.column(RuuviTagDataSQLite.dateColumn.name, .datetime).notNull()
            table.column(RuuviTagDataSQLite.sourceColumn.name, .text).notNull()
            table.column(RuuviTagDataSQLite.macColumn.name, .text)
            table.column(RuuviTagDataSQLite.rssiColumn.name, .integer)
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
