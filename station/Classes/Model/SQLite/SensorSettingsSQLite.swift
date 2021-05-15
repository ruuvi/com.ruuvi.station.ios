import Foundation
import GRDB

struct SensorSettingsSQLite: SensorSettings {
    var tagId: String
    var temperatureOffset: Double?
    var temperatureOffsetDate: Date?
    var humidityOffset: Double?
    var humidityOffsetDate: Date?
    var pressureOffset: Double?
    var pressureOffsetDate: Date?
}

extension SensorSettingsSQLite {
    static let idColumn = Column("id")
    static let tagIdColumn = Column("tagId")
    static let temperatureOffsetColumn = Column("temperatureOffset")
    static let temperatureOffsetDateColumn = Column("temperatureOffsetDate")
    static let humidityOffsetColumn = Column("humidityOffset")
    static let humidityOffsetDateColumn = Column("humidityOffsetDate")
    static let pressureOffsetColumn = Column("pressureOffset")
    static let pressureOffsetDateColumn = Column("pressureOffsetDate")
}

extension SensorSettingsSQLite: FetchableRecord {
    init(row: Row) {
        tagId = row[SensorSettingsSQLite.tagIdColumn]
        temperatureOffset = row[SensorSettingsSQLite.temperatureOffsetColumn]
        temperatureOffsetDate = row[SensorSettingsSQLite.temperatureOffsetDateColumn]
        humidityOffset = row[SensorSettingsSQLite.humidityOffsetColumn]
        humidityOffsetDate = row[SensorSettingsSQLite.humidityOffsetDateColumn]
        pressureOffset = row[SensorSettingsSQLite.pressureOffsetColumn]
        pressureOffsetDate = row[SensorSettingsSQLite.pressureOffsetDateColumn]
    }
}

extension SensorSettingsSQLite: PersistableRecord {
    static var databaseTableName: String {
        return "sensor_settings"
    }

    func encode(to container: inout PersistenceContainer) {
        container[SensorSettingsSQLite.idColumn] = id
        container[SensorSettingsSQLite.tagIdColumn] = tagId
        container[SensorSettingsSQLite.temperatureOffsetColumn] = temperatureOffset
        container[SensorSettingsSQLite.temperatureOffsetDateColumn] = temperatureOffsetDate
        container[SensorSettingsSQLite.humidityOffsetColumn] = humidityOffset
        container[SensorSettingsSQLite.humidityOffsetDateColumn] = humidityOffsetDate
        container[SensorSettingsSQLite.pressureOffsetColumn] = pressureOffset
        container[SensorSettingsSQLite.pressureOffsetDateColumn] = pressureOffsetDate
    }
}

extension SensorSettingsSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: SensorSettingsSQLite.databaseTableName, body: { table in
            table.column(RuuviTagDataSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(SensorSettingsSQLite.tagIdColumn.name, .text)
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
    var sensorSettings: SensorSettings {
        return SensorSettingsStruct(tagId: tagId,
                                    temperatureOffset: temperatureOffset,
                                    temperatureOffsetDate: temperatureOffsetDate,
                                    humidityOffset: humidityOffset,
                                    humidityOffsetDate: humidityOffsetDate,
                                    pressureOffset: pressureOffset,
                                    pressureOffsetDate: pressureOffsetDate)
    }
}
