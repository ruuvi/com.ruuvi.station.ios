import Foundation
import GRDB
import RuuviOntology

public struct RuuviCloudQueuedRequestSQLite: RuuviCloudQueuedRequest {
    public var id: Int64?
    public var type: RuuviCloudQueuedRequestType?
    public var status: RuuviCloudQueuedRequestStatusType?
    public var uniqueKey: String?
    public var requestDate: Date?
    public var successDate: Date?
    public var attempts: Int?
    public var requestBodyData: Data?
    public var additionalData: Data?

    public init(
        id: Int64?,
        type: RuuviCloudQueuedRequestType?,
        status: RuuviCloudQueuedRequestStatusType?,
        uniqueKey: String?,
        requestDate: Date?,
        successDate: Date?,
        attempts: Int?,
        requestBodyData: Data?,
        additionalData: Data?) {

        self.id = id
        self.type = type
        self.status = status
        self.uniqueKey = uniqueKey
        self.requestDate = requestDate
        self.successDate = successDate
        self.attempts = attempts
        self.requestBodyData = requestBodyData
        self.additionalData = additionalData
    }
}

extension RuuviCloudQueuedRequestSQLite {
    public static let idColumn = Column("id")
    public static let typeColumn = Column("requestType")
    public static let statusColumn = Column("statusType")
    public static let uniqueKeyColumn = Column("uniqueKey")
    public static let requestDateColumn = Column("requestDate")
    public static let successDateColumn = Column("successDate")
    public static let attemptsColumn = Column("attempts")
    public static let requestBodyDataColumn = Column("requestBodyData")
    public static let additionalDataColumn = Column("additionalData")
}

extension RuuviCloudQueuedRequestSQLite: FetchableRecord {
    public init(row: Row) {
        let idValue = Int64.fromDatabaseValue(row[RuuviCloudQueuedRequestSQLite.idColumn])
        id = idValue
        let typeValue = Int.fromDatabaseValue(row[RuuviCloudQueuedRequestSQLite.typeColumn])
        type = RuuviCloudQueuedRequestType(rawValue: typeValue ?? 0)
        let statusValue = Int.fromDatabaseValue(row[RuuviCloudQueuedRequestSQLite.statusColumn])
        status = RuuviCloudQueuedRequestStatusType(rawValue: statusValue ?? 0)
        uniqueKey = row[RuuviCloudQueuedRequestSQLite.uniqueKeyColumn]
        requestDate = row[RuuviCloudQueuedRequestSQLite.requestDateColumn]
        successDate = row[RuuviCloudQueuedRequestSQLite.successDateColumn]
        attempts = row[RuuviCloudQueuedRequestSQLite.attemptsColumn]
        requestBodyData = row[RuuviCloudQueuedRequestSQLite.requestBodyDataColumn]
        additionalData = row[RuuviCloudQueuedRequestSQLite.additionalDataColumn]
    }
}

extension RuuviCloudQueuedRequestSQLite: PersistableRecord {
    public static var databaseTableName: String {
        return "cloud_queued_requests"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviCloudQueuedRequestSQLite.idColumn] = id
        container[RuuviCloudQueuedRequestSQLite.typeColumn] = type?.rawValue
        container[RuuviCloudQueuedRequestSQLite.statusColumn] = status?.rawValue
        container[RuuviCloudQueuedRequestSQLite.uniqueKeyColumn] = uniqueKey
        container[RuuviCloudQueuedRequestSQLite.requestDateColumn] = requestDate
        container[RuuviCloudQueuedRequestSQLite.successDateColumn] = successDate
        container[RuuviCloudQueuedRequestSQLite.attemptsColumn] = attempts
        container[RuuviCloudQueuedRequestSQLite.requestBodyDataColumn] = requestBodyData
        container[RuuviCloudQueuedRequestSQLite.additionalDataColumn] = additionalData
    }
}

extension RuuviCloudQueuedRequestSQLite {
    public static func createTable(in db: Database) throws {
        try db.create(table: RuuviCloudQueuedRequestSQLite.databaseTableName, body: { table in
            table.autoIncrementedPrimaryKey(RuuviCloudQueuedRequestSQLite.idColumn.name,
                                            onConflict: .fail)
            table.column(RuuviCloudQueuedRequestSQLite.typeColumn.name, .integer)
            table.column(RuuviCloudQueuedRequestSQLite.statusColumn.name, .integer)
            table.column(RuuviCloudQueuedRequestSQLite.uniqueKeyColumn.name, .text)
            table.column(RuuviCloudQueuedRequestSQLite.requestDateColumn.name, .datetime)
            table.column(RuuviCloudQueuedRequestSQLite.successDateColumn.name, .datetime)
            table.column(RuuviCloudQueuedRequestSQLite.attemptsColumn.name, .integer)
            table.column(RuuviCloudQueuedRequestSQLite.requestBodyDataColumn.name, .blob)
            table.column(RuuviCloudQueuedRequestSQLite.additionalDataColumn.name, .blob)
        })
    }
}

extension RuuviCloudQueuedRequestSQLite {
    public var queuedRequest: RuuviCloudQueuedRequest {
        RuuviCloudQueuedRequestStruct(
            id: id,
            type: type,
            status: status,
            uniqueKey: uniqueKey,
            requestDate: requestDate,
            successDate: successDate,
            attempts: attempts,
            requestBodyData: requestBodyData,
            additionalData: additionalData
        )
    }
}

extension RuuviCloudQueuedRequest {
    public var sqlite: RuuviCloudQueuedRequestSQLite {
        return RuuviCloudQueuedRequestSQLite(
            id: id,
            type: type,
            status: status,
            uniqueKey: uniqueKey,
            requestDate: requestDate,
            successDate: successDate,
            attempts: attempts,
            requestBodyData: requestBodyData,
            additionalData: additionalData
        )
    }
}
