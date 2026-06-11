import Foundation
import GRDB

public struct RuuviUserSettingSQLite: RuuviUserSetting, Equatable {
    public var key: String
    public var value: String
    public var lastUpdated: Date?

    public init(
        key: String,
        value: String,
        lastUpdated: Date? = nil
    ) {
        self.key = key
        self.value = value
        self.lastUpdated = lastUpdated
    }
}

public extension RuuviUserSettingSQLite {
    static let keyColumn = Column("key")
    static let valueColumn = Column("value")
    static let lastUpdatedColumn = Column("lastUpdated")
}

extension RuuviUserSettingSQLite: FetchableRecord {
    public init(row: Row) {
        key = row[RuuviUserSettingSQLite.keyColumn]
        value = row[RuuviUserSettingSQLite.valueColumn]
        lastUpdated = row[RuuviUserSettingSQLite.lastUpdatedColumn]
    }
}

extension RuuviUserSettingSQLite: PersistableRecord {
    public static var databaseTableName: String {
        "user_settings"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviUserSettingSQLite.keyColumn] = key
        container[RuuviUserSettingSQLite.valueColumn] = value
        container[RuuviUserSettingSQLite.lastUpdatedColumn] = lastUpdated
    }
}

public extension RuuviUserSettingSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviUserSettingSQLite.databaseTableName, body: { table in
            table.column(RuuviUserSettingSQLite.keyColumn.name, .text)
                .notNull()
                .primaryKey(onConflict: .replace)
            table.column(RuuviUserSettingSQLite.valueColumn.name, .text)
                .notNull()
            table.column(RuuviUserSettingSQLite.lastUpdatedColumn.name, .datetime)
        })
    }
}

public extension RuuviUserSetting {
    var sqlite: RuuviUserSettingSQLite {
        RuuviUserSettingSQLite(
            key: key,
            value: value,
            lastUpdated: lastUpdated
        )
    }
}
