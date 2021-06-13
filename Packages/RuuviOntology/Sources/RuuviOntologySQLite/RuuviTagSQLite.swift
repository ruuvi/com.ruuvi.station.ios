import Foundation
import GRDB
import RuuviOntology

public struct RuuviTagSQLite: RuuviTagSensor {
    public var id: String
    public var macId: MACIdentifier?
    public var luid: LocalIdentifier?
    public var name: String
    public var version: Int
    public var isConnectable: Bool
    public var isClaimed: Bool
    public var isOwner: Bool
    public var owner: String?

    public init(
        id: String,
        macId: MACIdentifier?,
        luid: LocalIdentifier?,
        name: String,
        version: Int,
        isConnectable: Bool,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?
    ) {
        self.id = id
        self.macId = macId
        self.luid = luid
        self.name = name
        self.version = version
        self.isConnectable = isConnectable
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
    }
}

extension RuuviTagSQLite {
    public static let idColumn = Column("id")
    public static let macColumn = Column("mac")
    public static let luidColumn = Column("luid")
    public static let nameColumn = Column("name")
    public static let versionColumn = Column("version")
    public static let isConnectableColumn = Column("isConnectable")
    public static let networkProviderColumn = Column("networkProvider")
    public static let isClaimedColumn = Column("isClaimed")
    public static let isOwnerColumn = Column("isOwner")
    public static let owner = Column("owner")
}

extension RuuviTagSQLite: FetchableRecord {
    public init(row: Row) {
        id = row[RuuviTagSQLite.idColumn]
        if let macIdColumn = row[RuuviTagSQLite.macColumn] as? String {
            macId = MACIdentifierStruct(value: macIdColumn)
        }
        if let luidColumn = row[RuuviTagSQLite.luidColumn] as? String {
            luid = LocalIdentifierStruct(value: luidColumn)
        }
        name = row[RuuviTagSQLite.nameColumn]
        version = row[RuuviTagSQLite.versionColumn]
        isConnectable = row[RuuviTagSQLite.isConnectableColumn]
        isClaimed = row[RuuviTagSQLite.isClaimedColumn]
        isOwner = row[RuuviTagSQLite.isOwnerColumn]
        owner = row[RuuviTagSQLite.owner]
    }
}

extension RuuviTagSQLite: PersistableRecord {
    public static var databaseTableName: String {
        return "ruuvi_tag_sensors"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviTagSQLite.idColumn] = id
        container[RuuviTagSQLite.macColumn] = macId?.value
        container[RuuviTagSQLite.luidColumn] = luid?.value
        container[RuuviTagSQLite.nameColumn] = name
        container[RuuviTagSQLite.versionColumn] = version
        container[RuuviTagSQLite.isConnectableColumn] = isConnectable
        container[RuuviTagSQLite.isClaimedColumn] = isClaimed
        container[RuuviTagSQLite.isOwnerColumn] = isOwner
        container[RuuviTagSQLite.owner] = owner
    }
}

extension RuuviTagSQLite {
    public static func createTable(in db: Database) throws {
        try db.create(table: RuuviTagSQLite.databaseTableName, body: { table in
            table.column(RuuviTagSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .abort)
            table.column(RuuviTagSQLite.macColumn.name, .text)
            table.column(RuuviTagSQLite.luidColumn.name, .text)
            table.column(RuuviTagSQLite.nameColumn.name, .text).notNull()
            table.column(RuuviTagSQLite.versionColumn.name, .integer).notNull()
            table.column(RuuviTagSQLite.isConnectableColumn.name, .boolean).notNull()
            table.column(RuuviTagSQLite.isClaimedColumn.name, .boolean)
                .notNull()
                .defaults(to: false)
            table.column(RuuviTagSQLite.isOwnerColumn.name, .boolean)
                .notNull()
                .defaults(to: true)
            table.column(RuuviTagSQLite.owner.name, .text)
        })
    }
}
