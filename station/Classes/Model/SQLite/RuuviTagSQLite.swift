import Foundation
import GRDB
import RuuviOntology

struct RuuviTagSQLite: RuuviTagSensor {
    var id: String
    var macId: MACIdentifier?
    var luid: LocalIdentifier?
    var name: String
    var version: Int
    var isConnectable: Bool
    var isClaimed: Bool
    var isOwner: Bool
    var owner: String?
}

extension RuuviTagSQLite {
    static let idColumn = Column("id")
    static let macColumn = Column("mac")
    static let luidColumn = Column("luid")
    static let nameColumn = Column("name")
    static let versionColumn = Column("version")
    static let isConnectableColumn = Column("isConnectable")
    static let networkProviderColumn = Column("networkProvider")
    static let isClaimedColumn = Column("isClaimed")
    static let isOwnerColumn = Column("isOwner")
    static let owner = Column("owner")
}

extension RuuviTagSQLite: FetchableRecord {
    init(row: Row) {
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
    static var databaseTableName: String {
        return "ruuvi_tag_sensors"
    }

    func encode(to container: inout PersistenceContainer) {
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
    static func createTable(in db: Database) throws {
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
                .defaults(to: false)
            table.column(RuuviTagSQLite.owner.name, .text)
        })
    }
}
