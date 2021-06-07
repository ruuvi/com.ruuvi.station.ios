import Foundation
import GRDB
import RuuviOntology

public struct SensorSettingsSQLite: SensorSettings {
    public var luid: LocalIdentifier?
    public var macId: MACIdentifier?
    public var temperatureOffset: Double?
    public var temperatureOffsetDate: Date?
    public var humidityOffset: Double?
    public var humidityOffsetDate: Date?
    public var pressureOffset: Double?
    public var pressureOffsetDate: Date?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        temperatureOffset: Double?,
        temperatureOffsetDate: Date?,
        humidityOffset: Double?,
        humidityOffsetDate: Date?,
        pressureOffset: Double?,
        pressureOffsetDate: Date?
    ) {
        self.luid = luid
        self.macId = macId
        self.temperatureOffset = temperatureOffset
        self.temperatureOffsetDate = temperatureOffsetDate
        self.humidityOffset = humidityOffset
        self.humidityOffsetDate = humidityOffsetDate
        self.pressureOffset = pressureOffset
        self.pressureOffsetDate = pressureOffsetDate
    }
}

extension SensorSettingsSQLite {
    public static let idColumn = Column("id")
    public static let luidColumn = Column("luid")
    public static let macIdColumn = Column("macId")
    public static let temperatureOffsetColumn = Column("temperatureOffset")
    public static let temperatureOffsetDateColumn = Column("temperatureOffsetDate")
    public static let humidityOffsetColumn = Column("humidityOffset")
    public static let humidityOffsetDateColumn = Column("humidityOffsetDate")
    public static let pressureOffsetColumn = Column("pressureOffset")
    public static let pressureOffsetDateColumn = Column("pressureOffsetDate")
}

extension SensorSettingsSQLite: FetchableRecord {
    public init(row: Row) {
        if let luidValue = String.fromDatabaseValue(row[SensorSettingsSQLite.luidColumn]) {
            luid = LocalIdentifierStruct(value: luidValue)
        }
        if let macIdValue = String.fromDatabaseValue(row[SensorSettingsSQLite.macIdColumn]) {
            macId = MACIdentifierStruct(value: macIdValue)
        }
        temperatureOffset = row[SensorSettingsSQLite.temperatureOffsetColumn]
        temperatureOffsetDate = row[SensorSettingsSQLite.temperatureOffsetDateColumn]
        humidityOffset = row[SensorSettingsSQLite.humidityOffsetColumn]
        humidityOffsetDate = row[SensorSettingsSQLite.humidityOffsetDateColumn]
        pressureOffset = row[SensorSettingsSQLite.pressureOffsetColumn]
        pressureOffsetDate = row[SensorSettingsSQLite.pressureOffsetDateColumn]
    }
}

extension SensorSettingsSQLite: PersistableRecord {
    public static var databaseTableName: String {
        return "sensor_settings"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[SensorSettingsSQLite.idColumn] = id
        container[SensorSettingsSQLite.luidColumn] = luid?.value
        container[SensorSettingsSQLite.macIdColumn] = macId?.value
        container[SensorSettingsSQLite.temperatureOffsetColumn] = temperatureOffset
        container[SensorSettingsSQLite.temperatureOffsetDateColumn] = temperatureOffsetDate
        container[SensorSettingsSQLite.humidityOffsetColumn] = humidityOffset
        container[SensorSettingsSQLite.humidityOffsetDateColumn] = humidityOffsetDate
        container[SensorSettingsSQLite.pressureOffsetColumn] = pressureOffset
        container[SensorSettingsSQLite.pressureOffsetDateColumn] = pressureOffsetDate
    }
}

extension SensorSettingsSQLite {
    public static func createTable(in db: Database) throws {
        try db.create(table: SensorSettingsSQLite.databaseTableName, body: { table in
            table.column(RuuviTagDataSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(SensorSettingsSQLite.luidColumn.name, .text)
            table.column(SensorSettingsSQLite.macIdColumn.name, .text)
            table.column(SensorSettingsSQLite.temperatureOffsetColumn.name, .double)
            table.column(SensorSettingsSQLite.temperatureOffsetDateColumn.name, .datetime)
            table.column(SensorSettingsSQLite.humidityOffsetColumn.name, .double)
            table.column(SensorSettingsSQLite.humidityOffsetDateColumn.name, .datetime)
            table.column(SensorSettingsSQLite.pressureOffsetColumn.name, .double)
            table.column(SensorSettingsSQLite.pressureOffsetDateColumn.name, .datetime)
        })
    }
}

extension SensorSettingsSQLite {
    public var sensorSettings: SensorSettings {
        return SensorSettingsStruct(
            luid: luid,
            macId: macId,
            temperatureOffset: temperatureOffset,
            temperatureOffsetDate: temperatureOffsetDate,
            humidityOffset: humidityOffset,
            humidityOffsetDate: humidityOffsetDate,
            pressureOffset: pressureOffset,
            pressureOffsetDate: pressureOffsetDate
        )
    }
}
