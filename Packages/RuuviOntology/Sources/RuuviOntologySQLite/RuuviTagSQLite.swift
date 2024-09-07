import Foundation
import GRDB

public struct RuuviTagSQLite: RuuviTagSensor, Equatable {
    public var id: String
    public var macId: MACIdentifier?
    public var luid: LocalIdentifier?
    public var serviceUUID: String?
    public var name: String
    public var version: Int
    public var firmwareVersion: String?
    public var isConnectable: Bool
    public var isClaimed: Bool
    public var isOwner: Bool
    public var owner: String?
    public var ownersPlan: String?
    public var isCloudSensor: Bool?
    public var canShare: Bool
    public var sharedTo: [String]
    public var maxHistoryDays: Int?

    public init(
        id: String,
        macId: MACIdentifier?,
        luid: LocalIdentifier?,
        serviceUUID: String?,
        name: String,
        version: Int,
        firmwareVersion: String?,
        isConnectable: Bool,
        isClaimed: Bool,
        isOwner: Bool,
        owner: String?,
        ownersPlan: String?,
        isCloudSensor: Bool?,
        canShare: Bool,
        sharedTo: [String],
        maxHistoryDays: Int?
    ) {
        self.id = id
        self.macId = macId
        self.luid = luid
        self.serviceUUID = serviceUUID
        self.name = name
        self.version = version
        self.firmwareVersion = firmwareVersion
        self.isConnectable = isConnectable
        self.isClaimed = isClaimed
        self.isOwner = isOwner
        self.owner = owner
        self.ownersPlan = ownersPlan
        self.isCloudSensor = isCloudSensor
        self.canShare = canShare
        self.sharedTo = sharedTo
        self.maxHistoryDays = maxHistoryDays
    }

    public static func == (lhs: RuuviTagSQLite, rhs: RuuviTagSQLite) -> Bool {
        return lhs.id == rhs.id
        && lhs.macId?.any == rhs.macId?.any
        && lhs.luid?.any == rhs.luid?.any
        && lhs.serviceUUID == rhs.serviceUUID
        && lhs.name == rhs.name
        && lhs.version == rhs.version
        && lhs.firmwareVersion == rhs.firmwareVersion
        && lhs.isConnectable == rhs.isConnectable
        && lhs.isClaimed == rhs.isClaimed
        && lhs.isOwner == rhs.isOwner
        && lhs.owner == rhs.owner
        && lhs.ownersPlan == rhs.ownersPlan
        && lhs.isCloudSensor == rhs.isCloudSensor
        && lhs.canShare == rhs.canShare
        && lhs.sharedTo == rhs.sharedTo
        && lhs.maxHistoryDays == rhs.maxHistoryDays
    }
}

public extension RuuviTagSQLite {
    static let idColumn = Column("id")
    static let macColumn = Column("mac")
    static let luidColumn = Column("luid")
    static let serviceUUIDColumn = Column("serviceUUID")
    static let nameColumn = Column("name")
    static let versionColumn = Column("version")
    static let firmwareVersionColumn = Column("firmwareVersion")
    static let isConnectableColumn = Column("isConnectable")
    static let networkProviderColumn = Column("networkProvider")
    static let isClaimedColumn = Column("isClaimed")
    static let isOwnerColumn = Column("isOwner")
    static let owner = Column("owner")
    static let ownersPlan = Column("ownersPlan")
    static let isCloudSensor = Column("isCloudSensor")
    static let canShareColumn = Column("canShare")
    static let sharedToColumn = Column("sharedTo")
    static let maxHistoryDaysColumn = Column("maxHistoryDays")
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
        serviceUUID = row[RuuviTagSQLite.serviceUUIDColumn]
        name = row[RuuviTagSQLite.nameColumn]
        version = row[RuuviTagSQLite.versionColumn]
        firmwareVersion = row[RuuviTagSQLite.firmwareVersionColumn]
        isConnectable = row[RuuviTagSQLite.isConnectableColumn]
        isClaimed = row[RuuviTagSQLite.isClaimedColumn]
        isOwner = row[RuuviTagSQLite.isOwnerColumn]
        owner = row[RuuviTagSQLite.owner]
        ownersPlan = row[RuuviTagSQLite.ownersPlan]
        isCloudSensor = row[RuuviTagSQLite.isCloudSensor]
        canShare = row[RuuviTagSQLite.canShareColumn]
        maxHistoryDays = row[RuuviTagSQLite.maxHistoryDaysColumn]
        if let sharedToColumn = row[RuuviTagSQLite.sharedToColumn] as? String {
            sharedTo = sharedToColumn.components(separatedBy: ",")
        } else {
            sharedTo = []
        }
    }
}

extension RuuviTagSQLite: PersistableRecord {
    public static var databaseTableName: String {
        "ruuvi_tag_sensors"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviTagSQLite.idColumn] = id
        container[RuuviTagSQLite.macColumn] = macId?.value
        container[RuuviTagSQLite.luidColumn] = luid?.value
        container[RuuviTagSQLite.serviceUUIDColumn] = serviceUUID
        container[RuuviTagSQLite.nameColumn] = name
        container[RuuviTagSQLite.versionColumn] = version
        container[RuuviTagSQLite.firmwareVersionColumn] = firmwareVersion
        container[RuuviTagSQLite.isConnectableColumn] = isConnectable
        container[RuuviTagSQLite.isClaimedColumn] = isClaimed
        container[RuuviTagSQLite.isOwnerColumn] = isOwner
        container[RuuviTagSQLite.owner] = owner
        container[RuuviTagSQLite.ownersPlan] = ownersPlan
        container[RuuviTagSQLite.isCloudSensor] = isCloudSensor
        container[RuuviTagSQLite.canShareColumn] = canShare
        container[RuuviTagSQLite.sharedToColumn] = sharedTo.joined(separator: ",")
        container[RuuviTagSQLite.maxHistoryDaysColumn] = maxHistoryDays
    }
}

public extension RuuviTagSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviTagSQLite.databaseTableName, body: { table in
            table.column(RuuviTagSQLite.idColumn.name, .text).notNull().primaryKey(onConflict: .replace)
            table.column(RuuviTagSQLite.macColumn.name, .text)
            table.column(RuuviTagSQLite.luidColumn.name, .text)
            table.column(RuuviTagSQLite.serviceUUIDColumn.name, .text)
            table.column(RuuviTagSQLite.nameColumn.name, .text).notNull()
            table.column(RuuviTagSQLite.versionColumn.name, .integer).notNull()
            table.column(RuuviTagSQLite.firmwareVersionColumn.name, .text)
            table.column(RuuviTagSQLite.isConnectableColumn.name, .boolean).notNull()
            table.column(RuuviTagSQLite.isClaimedColumn.name, .boolean)
                .notNull()
                .defaults(to: false)
            table.column(RuuviTagSQLite.isOwnerColumn.name, .boolean)
                .notNull()
                .defaults(to: true)
            table.column(RuuviTagSQLite.owner.name, .text)
            table.column(RuuviTagSQLite.ownersPlan.name, .text)
            table.column(RuuviTagSQLite.isCloudSensor.name, .boolean)
            table.column(RuuviTagSQLite.canShareColumn.name, .boolean)
            table.column(RuuviTagSQLite.sharedToColumn.name, .text)
            table.column(RuuviTagSQLite.maxHistoryDaysColumn.name, .integer)
        })
    }
}
