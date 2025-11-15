import Foundation
import GRDB

public struct SensorSettingsSQLite: SensorSettings, Equatable {
    public var luid: LocalIdentifier?
    public var macId: MACIdentifier?
    public var temperatureOffset: Double?
    public var humidityOffset: Double?
    public var pressureOffset: Double?
    public var displayOrder: [String]?
    public var defaultDisplayOrder: Bool?

    public init(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        temperatureOffset: Double?,
        humidityOffset: Double?,
        pressureOffset: Double?,
        displayOrder: [String]? = nil,
        defaultDisplayOrder: Bool? = nil
    ) {
        self.luid = luid
        self.macId = macId
        self.temperatureOffset = temperatureOffset
        self.humidityOffset = humidityOffset
        self.pressureOffset = pressureOffset
        self.displayOrder = displayOrder
        self.defaultDisplayOrder = defaultDisplayOrder
    }

    public static func == (lhs: SensorSettingsSQLite, rhs: SensorSettingsSQLite) -> Bool {
        lhs.luid?.any == rhs.luid?.any
        && lhs.macId?.any == rhs.macId?.any
        && lhs.temperatureOffset == rhs.temperatureOffset
        && lhs.humidityOffset == rhs.humidityOffset
        && lhs.pressureOffset == rhs.pressureOffset
        && lhs.displayOrder == rhs.displayOrder
        && lhs.defaultDisplayOrder == rhs.defaultDisplayOrder
    }
}

public extension SensorSettingsSQLite {
    static let idColumn = Column("id")
    static let luidColumn = Column("luid")
    static let macIdColumn = Column("macId")
    static let temperatureOffsetColumn = Column("temperatureOffset")
    static let humidityOffsetColumn = Column("humidityOffset")
    static let pressureOffsetColumn = Column("pressureOffset")
    static let displayOrderColumn = Column("displayOrder")
    static let defaultDisplayOrderColumn = Column("defaultDisplayOrder")
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
        humidityOffset = row[SensorSettingsSQLite.humidityOffsetColumn]
        pressureOffset = row[SensorSettingsSQLite.pressureOffsetColumn]
        if let rawDisplayOrder: String = row[SensorSettingsSQLite.displayOrderColumn] {
            displayOrder = SensorSettingsSQLite.decodeDisplayOrder(rawDisplayOrder)
        } else {
            displayOrder = nil
        }
        defaultDisplayOrder = row[SensorSettingsSQLite.defaultDisplayOrderColumn]
    }
}

extension SensorSettingsSQLite: PersistableRecord {
    public static var databaseTableName: String {
        "sensor_settings"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[SensorSettingsSQLite.idColumn] = id
        container[SensorSettingsSQLite.luidColumn] = luid?.value
        container[SensorSettingsSQLite.macIdColumn] = macId?.value
        container[SensorSettingsSQLite.temperatureOffsetColumn] = temperatureOffset
        container[SensorSettingsSQLite.humidityOffsetColumn] = humidityOffset
        container[SensorSettingsSQLite.pressureOffsetColumn] = pressureOffset
        container[SensorSettingsSQLite.displayOrderColumn] = SensorSettingsSQLite
            .encodeDisplayOrder(displayOrder)
        container[SensorSettingsSQLite.defaultDisplayOrderColumn] = defaultDisplayOrder
    }
}

public extension SensorSettingsSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: SensorSettingsSQLite.databaseTableName, body: { table in
            table.column(SensorSettingsSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(SensorSettingsSQLite.luidColumn.name, .text)
            table.column(SensorSettingsSQLite.macIdColumn.name, .text)
            table.column(SensorSettingsSQLite.temperatureOffsetColumn.name, .double)
            table.column(SensorSettingsSQLite.humidityOffsetColumn.name, .double)
            table.column(SensorSettingsSQLite.pressureOffsetColumn.name, .double)
            table.column(SensorSettingsSQLite.displayOrderColumn.name, .text)
            table.column(SensorSettingsSQLite.defaultDisplayOrderColumn.name, .boolean)
        })
    }
}

public extension SensorSettingsSQLite {
    var sensorSettings: SensorSettings {
        SensorSettingsStruct(
            luid: luid,
            macId: macId,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }
}

public extension SensorSettings {
    var sqlite: SensorSettingsSQLite {
        SensorSettingsSQLite(
            luid: luid,
            macId: macId,
            temperatureOffset: temperatureOffset,
            humidityOffset: humidityOffset,
            pressureOffset: pressureOffset,
            displayOrder: displayOrder,
            defaultDisplayOrder: defaultDisplayOrder
        )
    }
}

public extension SensorSettingsSQLite {
    static func decodeDisplayOrder(_ raw: String) -> [String]? {
        guard !raw.isEmpty, let data = raw.data(using: .utf8) else {
            return nil
        }
        if let decoded = try? JSONDecoder().decode([String].self, from: data) {
            return decoded
        }
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
           let decoded = jsonObject as? [String] {
            return decoded
        }
        return nil
    }

    static func encodeDisplayOrder(_ codes: [String]?) -> String? {
        guard let codes = codes, !codes.isEmpty else {
            return nil
        }
        if let data = try? JSONEncoder().encode(codes) {
            return String(data: data, encoding: .utf8)
        }
        if let data = try? JSONSerialization.data(withJSONObject: codes, options: []),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
    }
}
