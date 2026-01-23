// swiftlint:disable file_length
import BTKit
import Foundation
import GRDB
import RuuviContext
import RuuviOntology

// swiftlint:disable type_body_length
public actor RuuviPersistenceSQLite: RuuviPersistence {
    public typealias Entity = RuuviTagSQLite
    typealias Record = RuuviTagDataSQLite
    typealias RecordLatest = RuuviTagLatestDataSQLite
    typealias Settings = SensorSettingsSQLite
    typealias QueuedRequest = RuuviCloudQueuedRequestSQLite
    typealias SensorSubscription = RuuviCloudSensorSubscriptionSQLite

    private var database: GRDBDatabase {
        context.database
    }

    private let context: SQLiteContext
    public init(context: SQLiteContext) {
        self.context = context
    }

    public func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let entity = Entity(
                    id: normalizedTag.id,
                    macId: normalizedTag.macId,
                    luid: normalizedTag.luid,
                    serviceUUID: normalizedTag.serviceUUID,
                    name: normalizedTag.name,
                    version: normalizedTag.version,
                    firmwareVersion: normalizedTag.firmwareVersion,
                    isConnectable: normalizedTag.isConnectable,
                    isClaimed: normalizedTag.isClaimed,
                    isOwner: normalizedTag.isOwner,
                    owner: normalizedTag.owner,
                    ownersPlan: normalizedTag.ownersPlan,
                    isCloudSensor: normalizedTag.isCloudSensor,
                    canShare: normalizedTag.canShare,
                    sharedTo: normalizedTag.sharedTo,
                    maxHistoryDays: normalizedTag.maxHistoryDays
                )
                try entity.insert(db)
            }
            return true
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.sqlite.insert(db)
            }
            return true
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.latest.insert(db)
            }
            return true
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.latest.update(db)
            }
            return true
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        do {
            try database.dbPool.write { db in
                for record in records {
                    assert(record.macId != nil)
                    let normalizedRecord = try normalizedRecord(record, db: db)
                    assert(normalizedRecord.macId != nil)
                    try normalizedRecord.sqlite.insert(db)
                }
            }
            return true
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readAll() async throws -> [AnyRuuviTagSensor] {
        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensor] in
                let request = Entity.order(Entity.versionColumn)
                return try request.fetchAll(db)
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        do {
            let entity = try database.dbPool.read { db -> Entity? in
                let request = Entity.filter(Entity.luidColumn == ruuviTagId || Entity.macColumn == ruuviTagId)
                return try request.fetchOne(db)
            }
            if let entity {
                return entity.any
            }
            throw RuuviPersistenceError.failedToFindRuuviTag
        } catch let error as RuuviPersistenceError {
            throw error
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensorRecord] in
                let request = Record.order(Record.dateColumn)
                    .filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                return try request.fetchAll(db)
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readAll(
        _ ruuviTagId: String,
        after date: Date
    ) async throws -> [RuuviTagSensorRecord] {
        let lastThree = ruuviTagId.lastThreeBytes
        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensorRecord] in
                let request = """
                SELECT *
                FROM ruuvi_tag_sensor_records rtsr
                WHERE rtsr.luid = ? OR rtsr.mac LIKE ?
                AND rtsr.date > ?
                ORDER BY date
                """
                return try Record.fetchAll(
                    db,
                    sql: request,
                    arguments: [ruuviTagId, "%\(lastThree)", date]
                )
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        let lastThree = ruuviTagId.lastThreeBytes
        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensorRecord] in
                let request = """
                SELECT *
                FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac LIKE ?) AND rtsr.date > ?
                GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / ?
                ORDER BY date
                """
                return try Record.fetchAll(
                    db,
                    sql: request,
                    arguments: [ruuviTagId, "%\(lastThree)", date, Int(interval)]
                )
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        let highDensityDate = Calendar.current.date(
            byAdding: .minute,
            value: -intervalMinutes,
            to: Date()
        ) ?? Date()
        let pruningInterval =
            (highDensityDate.timeIntervalSince1970 - date.timeIntervalSince1970) / points
        let lastThree = ruuviTagId.lastThreeBytes

        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensorRecord] in
                let request = """
                SELECT *
                FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac LIKE ?) AND rtsr.date > ? AND rtsr.date < ?
                GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / ?
                UNION ALL
                SELECT *
                FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac LIKE ?) AND rtsr.date > ?
                ORDER BY date
                """
                return try Record.fetchAll(
                    db,
                    sql: request,
                    arguments: [
                        ruuviTagId, "%\(lastThree)", date, highDensityDate, Int(pruningInterval),
                        ruuviTagId, "%\(lastThree)", highDensityDate,
                    ]
                )
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        let lastThree = ruuviTagId.lastThreeBytes
        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensorRecord] in
                let request = """
                SELECT *
                FROM ruuvi_tag_sensor_records rtsr
                WHERE rtsr.luid = ? OR rtsr.mac LIKE ?
                GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / ?
                ORDER BY date
                """
                return try Record.fetchAll(
                    db,
                    sql: request,
                    arguments: [ruuviTagId, "%\(lastThree)", Int(interval)]
                )
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readLast(
        _ ruuviTagId: String,
        from: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        do {
            let sqliteEntities = try database.dbPool.read { db -> [RuuviTagSensorRecord] in
                let request = Record.order(Record.dateColumn)
                    .filter((Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                        && Record.dateColumn > Date(timeIntervalSince1970: from))
                return try request.fetchAll(db)
            }
            return sqliteEntities.map(\.any)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        do {
            let sqliteRecord = try database.dbPool.read { db -> Record? in
                let request = Record.order(
                    Record.dateColumn.desc
                ).filter(
                        (
                            ruuviTag.luid?.value != nil && Record.luidColumn == ruuviTag.luid?.value
                        )
                        || (
                            ruuviTag.macId?.value != nil && Record.macColumn
                                .like(
                                "%\(ruuviTag.macId!.value.lastThreeBytes)"
                            )
                        )
                    )
                return try request.fetchOne(db)
            }
            return sqliteRecord
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        do {
            let sqliteRecord = try database.dbPool.read { db -> RecordLatest? in
                let request = RecordLatest.order(RecordLatest.dateColumn.desc)
                    .filter(
                        (
                            ruuviTag.luid?.value != nil && RecordLatest.luidColumn == ruuviTag.luid?.value
                        )
                        || (
                            ruuviTag.macId?.value != nil && RecordLatest.macColumn.like(
                                "%\(ruuviTag.macId!.value.lastThreeBytes)"
                            )
                        )
                    )
                return try request.fetchOne(db)
            }
            return sqliteRecord
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func deleteLatest(_ ruuviTagId: String) async throws -> Bool {
        do {
            let deletedCount = try database.dbPool.write { db -> Int in
                let request = RecordLatest
                    .filter(RecordLatest.luidColumn == ruuviTagId || RecordLatest.macColumn == ruuviTagId)
                return try request.deleteAll(db)
            }
            return deletedCount > 0
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let entity = Entity(
                    id: normalizedTag.id,
                    macId: normalizedTag.macId,
                    luid: normalizedTag.luid,
                    serviceUUID: normalizedTag.serviceUUID,
                    name: normalizedTag.name,
                    version: normalizedTag.version,
                    firmwareVersion: normalizedTag.firmwareVersion,
                    isConnectable: normalizedTag.isConnectable,
                    isClaimed: normalizedTag.isClaimed,
                    isOwner: normalizedTag.isOwner,
                    owner: normalizedTag.owner,
                    ownersPlan: normalizedTag.ownersPlan,
                    isCloudSensor: normalizedTag.isCloudSensor,
                    canShare: normalizedTag.canShare,
                    sharedTo: normalizedTag.sharedTo,
                    maxHistoryDays: normalizedTag.maxHistoryDays
                )
                try entity.update(db)
            }
            return true
        } catch let persistenceError as RuuviPersistenceError {
            throw persistenceError
        } catch let recordError as RecordError {
            if case .recordNotFound = recordError {
                throw RuuviPersistenceError.failedToFindRuuviTag
            }
            throw RuuviPersistenceError.grdb(recordError)
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        do {
            let success = try database.dbPool.write { db -> Bool in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let entity = Entity(
                    id: normalizedTag.id,
                    macId: normalizedTag.macId,
                    luid: normalizedTag.luid,
                    serviceUUID: normalizedTag.serviceUUID,
                    name: normalizedTag.name,
                    version: normalizedTag.version,
                    firmwareVersion: normalizedTag.firmwareVersion,
                    isConnectable: normalizedTag.isConnectable,
                    isClaimed: normalizedTag.isClaimed,
                    isOwner: normalizedTag.isOwner,
                    owner: normalizedTag.owner,
                    ownersPlan: normalizedTag.ownersPlan,
                    isCloudSensor: normalizedTag.isCloudSensor,
                    canShare: normalizedTag.canShare,
                    sharedTo: normalizedTag.sharedTo,
                    maxHistoryDays: normalizedTag.maxHistoryDays
                )
                return try entity.delete(db)
            }
            return success
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        do {
            let deletedCount = try database.dbPool.write { db -> Int in
                let request = Record.filter(
                    Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
                )
                return try request.deleteAll(db)
            }
            return deletedCount > 0
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        do {
            let deletedCount = try database.dbPool.write { db -> Int in
                let request = Record.filter(
                    Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
                ).filter(Record.dateColumn < date)
                return try request.deleteAll(db)
            }
            return deletedCount > 0
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func getStoredTagsCount() async throws -> Int {
        do {
            return try database.dbPool.read { db in
                try Entity.fetchCount(db)
            }
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func getStoredMeasurementsCount() async throws -> Int {
        do {
            return try database.dbPool.read { db in
                try Record.fetchCount(db)
            }
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        do {
            return try database.dbPool.read { db -> Settings? in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let request = Settings.filter(
                    (
                        normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value
                    )
                    || (
                        normalizedTag.macId?.value != nil && Settings.macIdColumn.like(
                            "%\(normalizedTag.macId!.value.lastThreeBytes)"
                        )
                    )
                )
                return try request.fetchOne(db)
            }
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func save(
        sensorSettings: SensorSettings
    ) async throws -> SensorSettings {
        do {
            try database.dbPool.write { db in
                try sensorSettings.sqlite.save(db)
            }
            return sensorSettings
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    // swiftlint:disable:next function_body_length
    public func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        assert(ruuviTag.macId != nil)
        do {
            let settings: Settings = try database.dbPool.write { db in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                var isAddNewRecord = true
                var sqliteSensorSettings = Settings(
                    luid: normalizedTag.luid,
                    macId: normalizedTag.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
                let request = Settings.filter(
                    (
                        normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value
                    )
                    || (
                        normalizedTag.macId?.value != nil && Settings.macIdColumn.like(
                            "%\(normalizedTag.macId!.value.lastThreeBytes)"
                        )
                    )
                )
                if let existingSettings = try request.fetchOne(db) {
                    sqliteSensorSettings = existingSettings
                    isAddNewRecord = false
                }

                switch type {
                case .humidity:
                    sqliteSensorSettings.humidityOffset = value
                case .pressure:
                    sqliteSensorSettings.pressureOffset = value
                default:
                    sqliteSensorSettings.temperatureOffset = value
                }

                if isAddNewRecord {
                    try sqliteSensorSettings.insert(db)
                } else {
                    try sqliteSensorSettings.update(db)
                }

                if let sqliteSensorRecord = record {
                    let normalizedRecord = try normalizedRecord(sqliteSensorRecord, db: db)
                    try normalizedRecord.sqlite.insert(db)
                }

                return sqliteSensorSettings
            }
            return settings
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?
    ) async throws -> SensorSettings {
        do {
            let settings: Settings = try database.dbPool.write { db in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                var seed = Settings(
                    luid: normalizedTag.luid,
                    macId: normalizedTag.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
                seed.displayOrder = displayOrder
                seed.defaultDisplayOrder = defaultDisplayOrder

                try db.execute(sql: """
                INSERT INTO \(Settings.databaseTableName)
                    (\(Settings.idColumn.name), \(Settings.luidColumn.name), \(Settings.macIdColumn.name),
                     \(Settings.displayOrderColumn.name), \(Settings.defaultDisplayOrderColumn.name))
                VALUES (:id, :luid, :macId, :displayOrder, :defaultDisplayOrder)
                ON CONFLICT(\(Settings.idColumn.name)) DO UPDATE SET
                    \(Settings.displayOrderColumn.name) = excluded.\(Settings.displayOrderColumn.name),
                    \(Settings.defaultDisplayOrderColumn.name) = excluded.\(Settings.defaultDisplayOrderColumn.name),
                    \(Settings.luidColumn.name) = COALESCE(excluded.\(Settings.luidColumn.name),
                        \(Settings.databaseTableName).\(Settings.luidColumn.name)),
                    \(Settings.macIdColumn.name) = COALESCE(excluded.\(Settings.macIdColumn.name),
                        \(Settings.databaseTableName).\(Settings.macIdColumn.name))
                """, arguments: [
                    "id": seed.id,
                    "luid": normalizedTag.luid?.value,
                    "macId": normalizedTag.macId?.value,
                    "displayOrder": SensorSettingsSQLite.encodeDisplayOrder(displayOrder),
                    "defaultDisplayOrder": defaultDisplayOrder,
                ])

                let request = Settings.filter(Settings.idColumn == seed.id)
                if let updated = try request.fetchOne(db) {
                    return updated
                } else {
                    return seed
                }
            }
            return settings
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        do {
            let success = try database.dbPool.write { db -> Bool in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let request = Settings.filter(
                    (
                        normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value
                    )
                    || (
                        normalizedTag.macId?.value != nil && Settings.macIdColumn.like(
                            "%\(normalizedTag.macId!.value.lastThreeBytes)"
                        )
                    )
                )
                let sensorSettings: Settings? = try request.fetchOne(db)
                if let notNullSensorSettings = sensorSettings {
                    return try notNullSensorSettings.delete(db)
                }
                return false
            }
            return success
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func deleteSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> Bool {
        do {
            let deletedCount = try database.dbPool.write { db -> Int in
                let settingsId = SensorSettingsStruct(
                    luid: ruuviTag.luid,
                    macId: ruuviTag.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil,
                ).id

                var filter = Settings.idColumn == settingsId

                if let luidValue = ruuviTag.luid?.value {
                    filter = filter || Settings.luidColumn == luidValue
                }

                if let macValue = ruuviTag.macId?.value {
                    filter = filter || Settings.macIdColumn == macValue
                    filter = filter || Settings.macIdColumn.like("%\(macValue.lastThreeBytes)")
                }

                let request = Settings.filter(filter)
                return try request.deleteAll(db)
            }
            return deletedCount > 0
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func cleanupDBSpace() async throws -> Bool {
        do {
            try database.dbPool.vacuum()
            return true
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    // MARK: - Queued cloud requests

    @discardableResult
    public func readQueuedRequests()
    async throws -> [RuuviCloudQueuedRequest] {
        do {
            let sqliteEntities = try database.dbPool.read { db -> [QueuedRequest] in
                let request = QueuedRequest.order(QueuedRequest.requestDateColumn)
                return try request.fetchAll(db)
            }
            return sqliteEntities.map { $0 as RuuviCloudQueuedRequest }
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    @discardableResult
    public func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest] {
        let requests = try await readQueuedRequests()
        return requests.filter { req in
            req.uniqueKey != nil && req.uniqueKey == key
        }
    }

    @discardableResult
    public func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest] {
        let requests = try await readQueuedRequests()
        return requests.filter { req in
            req.type != nil && req.type == type
        }
    }

    @discardableResult
    public func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        // Check if there's already a request stored for the key.
        // If exists update the existing record, otherwise create a new.
        let requests = try await readQueuedRequests()
        let existingRequest = requests.first(
            where: { ($0.uniqueKey != nil && $0.uniqueKey == request.uniqueKey)
                && ($0.type != nil && $0.type == request.type)
            }
        )
        let isCreate = requests.isEmpty || existingRequest == nil

        return try await createQueueRequest(
            isCreate: isCreate,
            newRequest: request,
            existingRequest: existingRequest
        )
    }

    @discardableResult
    public func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        assert(request.id != nil)
        let entity = QueuedRequest(
            id: request.id,
            type: request.type,
            status: request.status,
            uniqueKey: request.uniqueKey,
            requestDate: request.requestDate,
            successDate: request.successDate,
            attempts: request.attempts,
            requestBodyData: request.requestBodyData,
            additionalData: request.additionalData
        )
        do {
            let success = try database.dbPool.write { db -> Bool in
                try entity.delete(db)
            }
            return success
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    @discardableResult
    public func deleteQueuedRequests() async throws -> Bool {
        do {
            let deletedCount = try database.dbPool.write { db -> Int in
                try QueuedRequest.deleteAll(db)
            }
            return deletedCount > 0
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    // MARK: - Subscription
    public func save(
        subscription: CloudSensorSubscription
    ) async throws -> CloudSensorSubscription {
        do {
            try database.dbPool.write { db in
                try subscription.sqlite.save(db)
            }
            return subscription
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        do {
            return try database.dbPool.read { db -> CloudSensorSubscription? in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let request = SensorSubscription.filter(
                    normalizedTag.macId?.value != nil
                    && SensorSubscription.macIdColumn == normalizedTag.macId?.value
                )
                return try request.fetchOne(db)
            }
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }
}

// MARK: - Private

extension RuuviPersistenceSQLite {
    /// Create or Update a queued request.
    private func createQueueRequest(
        isCreate: Bool,
        newRequest: RuuviCloudQueuedRequest,
        existingRequest: RuuviCloudQueuedRequest?
    )
    async throws -> Bool {
        if isCreate {
            do {
                try database.dbPool.write { db in
                    assert(newRequest.uniqueKey != nil)
                    try newRequest.sqlite.insert(db)
                }
                return true
            } catch {
                throw RuuviPersistenceError.grdb(error)
            }
        } else {
            guard let existingRequest else {
                return false
            }

            let retryCount = existingRequest.attempts ?? 0 + 1
            let entity = QueuedRequest(
                id: existingRequest.id,
                type: existingRequest.type,
                status: newRequest.status,
                uniqueKey: newRequest.uniqueKey,
                requestDate: newRequest.requestDate,
                successDate: newRequest.successDate,
                attempts: retryCount,
                requestBodyData: newRequest.requestBodyData,
                additionalData: newRequest.additionalData
            )
            do {
                try database.dbPool.write { db in
                    try entity.update(db)
                }
                return true
            } catch {
                throw RuuviPersistenceError.grdb(error)
            }
        }
    }

    private func normalizedSensor(
        _ sensor: RuuviTagSensor,
        db: Database
    ) throws -> RuuviTagSensor {
        guard
            let normalizedMac = try normalizedMacId(
                macId: sensor.macId,
                luid: sensor.luid,
                db: db
            ),
            let currentMac = sensor.macId
        else {
            return sensor
        }

        if currentMac.value == normalizedMac.value {
            return sensor
        }

        if currentMac.value.isLast3BytesEqual(to: normalizedMac.value) {
            return sensor.with(macId: normalizedMac)
        }

        return sensor
    }

    private func normalizedRecord(
        _ record: RuuviTagSensorRecord,
        db: Database
    ) throws -> RuuviTagSensorRecord {
        guard
            let normalizedMac = try normalizedMacId(
                macId: record.macId,
                luid: record.luid,
                db: db
            ),
            let currentMac = record.macId
        else {
            return record
        }

        if currentMac.value == normalizedMac.value {
            return record
        }

        if currentMac.value.isLast3BytesEqual(to: normalizedMac.value) {
            return record.with(macId: normalizedMac)
        }

        return record
    }

    private func normalizedMacId(
        macId: MACIdentifier?,
        luid: LocalIdentifier?,
        db: Database
    ) throws -> MACIdentifier? {
        guard let macId else {
            return nil
        }

        if let luid,
           let existing = try Entity
            .filter(Entity.luidColumn == luid.value)
            .fetchOne(db)?.macId {
            return existing
        }

        if let existingExact = try Entity
            .filter(Entity.macColumn == macId.value)
            .fetchOne(db)?.macId {
            return existingExact
        }

        let candidates = try fetchCandidateMacsMatchingSuffix(of: macId, db: db)
        if candidates.count == 1 {
            return candidates[0]
        }

        return macId
    }

    private func fetchCandidateMacsMatchingSuffix(
        of macId: MACIdentifier,
        db: Database
    ) throws -> [MACIdentifier] {
        var matches = [MACIdentifier]()
        let suffix = macId.value.lastThreeBytes

        if !suffix.isEmpty {
            let likeMatches = try Entity
                .filter(Entity.macColumn.like("%\(suffix)"))
                .fetchAll(db)
                .compactMap(\.macId)
                .filter { $0.value.isLast3BytesEqual(to: macId.value) }
            matches.append(contentsOf: likeMatches)
        }

        if matches.isEmpty {
            let allMatches = try Entity
                .fetchAll(db)
                .compactMap(\.macId)
                .filter { $0.value.isLast3BytesEqual(to: macId.value) }
            matches.append(contentsOf: allMatches)
        }

        return matches
    }
}

private extension String {
    /// Returns the last 3 bytes of a MAC address (e.g., "DD:EE:FF" from "AA:BB:CC:DD:EE:FF")
    var lastThreeBytes: String {
        let components = self.components(separatedBy: ":")
        guard components.count >= 3 else { return self }
        return components.suffix(3).joined(separator: ":")
    }
}

private extension Optional where Wrapped == String {
    var lastThreeBytes: String? {
        self?.lastThreeBytes
    }
}

// swiftlint:enable file_length type_body_length
