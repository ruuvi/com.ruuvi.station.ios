import Foundation
import GRDB

public struct RuuviCloudSensorSubscriptionSQLite: CloudSensorSubscription, Equatable {

    public var macId: String?
    public var subscriptionName: String?
    public var isActive: Bool?
    public var maxClaims: Int?
    public var maxHistoryDays: Int?
    public var maxResolutionMinutes: Int?
    public var maxShares: Int?
    public var maxSharesPerSensor: Int?
    public var delayedAlertAllowed: Bool?
    public var emailAlertAllowed: Bool?
    public var offlineAlertAllowed: Bool?
    public var pdfExportAllowed: Bool?
    public var pushAlertAllowed: Bool?
    public var telegramAlertAllowed: Bool?
    public var endAt: String?

    public static func == (
        lhs: RuuviCloudSensorSubscriptionSQLite,
        rhs: RuuviCloudSensorSubscriptionSQLite
    ) -> Bool {
        return lhs.macId == rhs.macId &&
            lhs.subscriptionName == rhs.subscriptionName &&
            lhs.isActive == rhs.isActive &&
            lhs.maxClaims == rhs.maxClaims &&
            lhs.maxHistoryDays == rhs.maxHistoryDays &&
            lhs.maxResolutionMinutes == rhs.maxResolutionMinutes &&
            lhs.maxShares == rhs.maxShares &&
            lhs.maxSharesPerSensor == rhs.maxSharesPerSensor &&
            lhs.delayedAlertAllowed == rhs.delayedAlertAllowed &&
            lhs.emailAlertAllowed == rhs.emailAlertAllowed &&
            lhs.offlineAlertAllowed == rhs.offlineAlertAllowed &&
            lhs.pdfExportAllowed == rhs.pdfExportAllowed &&
            lhs.pushAlertAllowed == rhs.pushAlertAllowed &&
            lhs.telegramAlertAllowed == rhs.telegramAlertAllowed &&
            lhs.endAt == rhs.endAt
    }
}

public extension RuuviCloudSensorSubscriptionSQLite {
    static let idColumn = Column("id")
    static let macIdColumn = Column("macId")
    static let subscriptionNameColumn = Column("subscriptionName")
    static let isActiveColumn = Column("isActive")
    static let maxClaimsColumn = Column("maxClaims")
    static let maxHistoryDaysColumn = Column("maxHistoryDays")
    static let maxResolutionMinutesColumn = Column("maxResolutionMinutes")
    static let maxSharesColumn = Column("maxShares")
    static let maxSharesPerSensorColumn = Column("maxSharesPerSensor")
    static let delayedAlertAllowedColumn = Column("delayedAlertAllowed")
    static let emailAlertAllowedColumn = Column("emailAlertAllowed")
    static let offlineAlertAllowedColumn = Column("offlineAlertAllowed")
    static let pdfExportAllowedColumn = Column("pdfExportAllowed")
    static let pushAlertAllowedColumn = Column("pushAlertAllowed")
    static let telegramAlertAllowedColumn = Column("telegramAlertAllowed")
    static let endAtColumn = Column("endAt")
}

extension RuuviCloudSensorSubscriptionSQLite: FetchableRecord {
    public init(row: Row) {
        macId = row[RuuviCloudSensorSubscriptionSQLite.macIdColumn]
        subscriptionName = row[RuuviCloudSensorSubscriptionSQLite.subscriptionNameColumn]
        isActive = row[RuuviCloudSensorSubscriptionSQLite.isActiveColumn]
        maxClaims = row[RuuviCloudSensorSubscriptionSQLite.maxClaimsColumn]
        maxHistoryDays = row[RuuviCloudSensorSubscriptionSQLite.maxHistoryDaysColumn]
        maxResolutionMinutes = row[RuuviCloudSensorSubscriptionSQLite.maxResolutionMinutesColumn]
        maxShares = row[RuuviCloudSensorSubscriptionSQLite.maxSharesColumn]
        maxSharesPerSensor = row[RuuviCloudSensorSubscriptionSQLite.maxSharesPerSensorColumn]
        delayedAlertAllowed = row[RuuviCloudSensorSubscriptionSQLite.delayedAlertAllowedColumn]
        emailAlertAllowed = row[RuuviCloudSensorSubscriptionSQLite.emailAlertAllowedColumn]
        offlineAlertAllowed = row[RuuviCloudSensorSubscriptionSQLite.offlineAlertAllowedColumn]
        pdfExportAllowed = row[RuuviCloudSensorSubscriptionSQLite.pdfExportAllowedColumn]
        pushAlertAllowed = row[RuuviCloudSensorSubscriptionSQLite.pushAlertAllowedColumn]
        telegramAlertAllowed = row[RuuviCloudSensorSubscriptionSQLite.telegramAlertAllowedColumn]
        endAt = row[RuuviCloudSensorSubscriptionSQLite.endAtColumn]
    }
}

extension RuuviCloudSensorSubscriptionSQLite: PersistableRecord {
    public static var databaseTableName: String {
        return "ruuvi_cloud_sensor_subscription"
    }

    public func encode(to container: inout PersistenceContainer) {
        container[RuuviCloudSensorSubscriptionSQLite.idColumn] = id
        container[RuuviCloudSensorSubscriptionSQLite.macIdColumn] = macId
        container[RuuviCloudSensorSubscriptionSQLite.subscriptionNameColumn] = subscriptionName
        container[RuuviCloudSensorSubscriptionSQLite.isActiveColumn] = isActive
        container[RuuviCloudSensorSubscriptionSQLite.maxClaimsColumn] = maxClaims
        container[RuuviCloudSensorSubscriptionSQLite.maxHistoryDaysColumn] = maxHistoryDays
        container[RuuviCloudSensorSubscriptionSQLite.maxResolutionMinutesColumn] = maxResolutionMinutes
        container[RuuviCloudSensorSubscriptionSQLite.maxSharesColumn] = maxShares
        container[RuuviCloudSensorSubscriptionSQLite.maxSharesPerSensorColumn] = maxSharesPerSensor
        container[RuuviCloudSensorSubscriptionSQLite.delayedAlertAllowedColumn] = delayedAlertAllowed
        container[RuuviCloudSensorSubscriptionSQLite.emailAlertAllowedColumn] = emailAlertAllowed
        container[RuuviCloudSensorSubscriptionSQLite.offlineAlertAllowedColumn] = offlineAlertAllowed
        container[RuuviCloudSensorSubscriptionSQLite.pdfExportAllowedColumn] = pdfExportAllowed
        container[RuuviCloudSensorSubscriptionSQLite.pushAlertAllowedColumn] = pushAlertAllowed
        container[RuuviCloudSensorSubscriptionSQLite.telegramAlertAllowedColumn] = telegramAlertAllowed
        container[RuuviCloudSensorSubscriptionSQLite.endAtColumn] = endAt
    }
}

public extension RuuviCloudSensorSubscriptionSQLite {
    static func createTable(in db: Database) throws {
        try db.create(table: RuuviCloudSensorSubscriptionSQLite.databaseTableName) { table in
            table.column(
                RuuviCloudSensorSubscriptionSQLite.idColumn.name,
                .text
            ).notNull().primaryKey(
                onConflict: .replace
            )
            table.column(RuuviCloudSensorSubscriptionSQLite.macIdColumn.name, .text).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.subscriptionNameColumn.name, .text).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.isActiveColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.maxClaimsColumn.name, .integer).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.maxHistoryDaysColumn.name, .integer).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.maxResolutionMinutesColumn.name, .integer).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.maxSharesColumn.name, .integer).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.maxSharesPerSensorColumn.name, .integer).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.delayedAlertAllowedColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.emailAlertAllowedColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.offlineAlertAllowedColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.pdfExportAllowedColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.pushAlertAllowedColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.telegramAlertAllowedColumn.name, .boolean).notNull()
            table.column(RuuviCloudSensorSubscriptionSQLite.endAtColumn.name, .text).notNull()
        }
    }
}

public extension CloudSensorSubscription {
    var sqlite: RuuviCloudSensorSubscriptionSQLite {
        RuuviCloudSensorSubscriptionSQLite(
            macId: macId,
            subscriptionName: subscriptionName,
            isActive: isActive,
            maxClaims: maxClaims,
            maxHistoryDays: maxHistoryDays,
            maxResolutionMinutes: maxResolutionMinutes,
            maxShares: maxShares,
            maxSharesPerSensor: maxSharesPerSensor,
            delayedAlertAllowed: delayedAlertAllowed,
            emailAlertAllowed: emailAlertAllowed,
            offlineAlertAllowed: offlineAlertAllowed,
            pdfExportAllowed: pdfExportAllowed,
            pushAlertAllowed: pushAlertAllowed,
            telegramAlertAllowed: telegramAlertAllowed,
            endAt: endAt
        )
    }
}
