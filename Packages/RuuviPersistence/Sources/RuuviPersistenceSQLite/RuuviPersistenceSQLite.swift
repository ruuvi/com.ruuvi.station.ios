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

    private let context: SQLiteContext

    private var database: GRDBDatabase {
        context.database
    }

    public init(context: SQLiteContext) {
        self.context = context
    }

    public func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        return try write { db in
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
                maxHistoryDays: normalizedTag.maxHistoryDays,
                lastUpdated: normalizedTag.lastUpdated
            )
            try entity.insert(db)
            return true
        }
    }

    public func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        return try write { db in
            let normalizedRecord = try normalizedRecord(record, db: db)
            assert(normalizedRecord.macId != nil)
            try normalizedRecord.sqlite.insert(db)
            return true
        }
    }

    public func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        return try write { db in
            let normalizedRecord = try normalizedRecord(record, db: db)
            assert(normalizedRecord.macId != nil)
            try normalizedRecord.latest.insert(db)
            return true
        }
    }

    public func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        return try write { db in
            let normalizedRecord = try normalizedRecord(record, db: db)
            assert(normalizedRecord.macId != nil)
            try normalizedRecord.latest.update(db)
            return true
        }
    }

    public func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        try write { db in
            for record in records {
                assert(record.macId != nil)
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.sqlite.insert(db)
            }
            return true
        }
    }

    public func readAll() async throws -> [AnyRuuviTagSensor] {
        try read { db in
            try Entity
                .order(Entity.versionColumn)
                .fetchAll(db)
                .map(\.any)
        }
    }

    public func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        try read { db in
            let request = Entity.filter(Entity.luidColumn == ruuviTagId || Entity.macColumn == ruuviTagId)
            guard let entity = try request.fetchOne(db) else {
                throw RuuviPersistenceError.failedToFindRuuviTag
            }
            return entity.any
        }
    }

    public func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        try read { db in
            try Record
                .order(Record.dateColumn)
                .filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                .fetchAll(db)
                .map(\.any)
        }
    }

    public func readAll(
        _ ruuviTagId: String,
        after date: Date
    ) async throws -> [RuuviTagSensorRecord] {
        let lastThree = ruuviTagId.lastThreeBytes
        return try read { db in
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
            ).map(\.any)
        }
    }

    public func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        let lastThree = ruuviTagId.lastThreeBytes
        return try read { db in
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
            ).map(\.any)
        }
    }

    public func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        let highDensityDate = Date().addingTimeInterval(TimeInterval(-intervalMinutes * 60))
        let pruningInterval =
            (highDensityDate.timeIntervalSince1970 - date.timeIntervalSince1970) / points
        let lastThree = ruuviTagId.lastThreeBytes

        return try read { db in
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
            ).map(\.any)
        }
    }

    public func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        let lastThree = ruuviTagId.lastThreeBytes
        return try read { db in
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
            ).map(\.any)
        }
    }

    public func readLast(
        _ ruuviTagId: String,
        from: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        try read { db in
            try Record
                .order(Record.dateColumn)
                .filter(
                    (Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                        && Record.dateColumn > Date(timeIntervalSince1970: from)
                )
                .fetchAll(db)
                .map(\.any)
        }
    }

    public func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        try read { db in
            guard let filter = identifierFilter(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                luidColumn: Record.luidColumn,
                macColumn: Record.macColumn
            ) else { return nil }
            let request = Record.order(Record.dateColumn.desc).filter(filter)
            return try request.fetchOne(db)
        }
    }

    public func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        try read { db in
            guard let filter = identifierFilter(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                luidColumn: RecordLatest.luidColumn,
                macColumn: RecordLatest.macColumn
            ) else { return nil }
            let request = RecordLatest.order(RecordLatest.dateColumn.desc).filter(filter)
            return try request.fetchOne(db)
        }
    }

    public func deleteLatest(_ ruuviTagId: String) async throws -> Bool {
        try write { db in
            let request = RecordLatest
                .filter(RecordLatest.luidColumn == ruuviTagId || RecordLatest.macColumn == ruuviTagId)
            return try request.deleteAll(db) > 0
        }
    }

    public func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        return try write { db in
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
                maxHistoryDays: normalizedTag.maxHistoryDays,
                lastUpdated: normalizedTag.lastUpdated
            )
            try entity.update(db)
            return true
        }
    }

    public func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        return try write { db in
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
    }

    public func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        try write { db in
            let request = Record.filter(
                Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
            )
            return try request.deleteAll(db) > 0
        }
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        try write { db in
            let request = Record
                .filter(Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)"))
                .filter(Record.dateColumn < date)
            return try request.deleteAll(db) > 0
        }
    }

    public func getStoredTagsCount() async throws -> Int {
        try read { db in
            try Entity.fetchCount(db)
        }
    }

    public func getStoredMeasurementsCount() async throws -> Int {
        try read { db in
            try Record.fetchCount(db)
        }
    }

    public func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        try read { db in
            let normalizedTag = try normalizedSensor(ruuviTag, db: db)
            guard let filter = identifierFilter(
                luid: normalizedTag.luid,
                macId: normalizedTag.macId,
                luidColumn: Settings.luidColumn,
                macColumn: Settings.macIdColumn
            ) else { return nil }
            let request = Settings.filter(filter)
            return try request.fetchOne(db)
        }
    }

    public func save(sensorSettings: SensorSettings) async throws -> SensorSettings {
        try write { db in
            try sensorSettings.sqlite.save(db)
            return sensorSettings
        }
    }

    public func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        assert(ruuviTag.macId != nil)
        return try write { db in
            let normalizedTag = try normalizedSensor(ruuviTag, db: db)
            var isAddNewRecord = true
            var sqliteSensorSettings = Settings(
                luid: normalizedTag.luid,
                macId: normalizedTag.macId,
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: nil
            )
            let existingSettings = try identifierFilter(
                luid: normalizedTag.luid,
                macId: normalizedTag.macId,
                luidColumn: Settings.luidColumn,
                macColumn: Settings.macIdColumn
            ).flatMap { filter in
                try Settings.filter(filter).fetchOne(db)
            }
            if let existingSettings {
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
    }

    public func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws -> SensorSettings {
        try write { db in
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
            seed.displayOrderLastUpdated = displayOrderLastUpdated
            seed.defaultDisplayOrderLastUpdated = defaultDisplayOrderLastUpdated

            try db.execute(sql: """
            INSERT INTO \(Settings.databaseTableName)
                (\(Settings.idColumn.name), \(Settings.luidColumn.name), \(Settings.macIdColumn.name),
                 \(Settings.displayOrderColumn.name), \(Settings.defaultDisplayOrderColumn.name),
                 \(Settings.displayOrderLastUpdatedColumn.name),
                 \(Settings.defaultDisplayOrderLastUpdatedColumn.name))
            VALUES (:id, :luid, :macId, :displayOrder, :defaultDisplayOrder,
                    :displayOrderLastUpdated, :defaultDisplayOrderLastUpdated)
            ON CONFLICT(\(Settings.idColumn.name)) DO UPDATE SET
                \(Settings.displayOrderColumn.name) = excluded.\(Settings.displayOrderColumn.name),
                \(Settings.defaultDisplayOrderColumn.name) = excluded.\(Settings.defaultDisplayOrderColumn.name),
                \(Settings.displayOrderLastUpdatedColumn.name)
                    = excluded.\(Settings.displayOrderLastUpdatedColumn.name),
                \(Settings.defaultDisplayOrderLastUpdatedColumn.name)
                    = excluded.\(Settings.defaultDisplayOrderLastUpdatedColumn.name),
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
                "displayOrderLastUpdated": displayOrderLastUpdated,
                "defaultDisplayOrderLastUpdated": defaultDisplayOrderLastUpdated,
            ])

            let request = Settings.filter(Settings.idColumn == seed.id)
            return try request.fetchOne(db)!
        }
    }

    public func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws -> SensorSettings {
        try write { db in
            let normalizedTag = try normalizedSensor(ruuviTag, db: db)
            var seed = Settings(
                luid: normalizedTag.luid,
                macId: normalizedTag.macId,
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: nil
            )
            seed.description = description
            seed.descriptionLastUpdated = descriptionLastUpdated

            try db.execute(sql: """
            INSERT INTO \(Settings.databaseTableName)
                (\(Settings.idColumn.name), \(Settings.luidColumn.name), \(Settings.macIdColumn.name),
                 \(Settings.descriptionColumn.name), \(Settings.descriptionLastUpdatedColumn.name))
            VALUES (:id, :luid, :macId, :description, :descriptionLastUpdated)
            ON CONFLICT(\(Settings.idColumn.name)) DO UPDATE SET
                \(Settings.descriptionColumn.name) = excluded.\(Settings.descriptionColumn.name),
                \(Settings.descriptionLastUpdatedColumn.name)
                    = excluded.\(Settings.descriptionLastUpdatedColumn.name),
                \(Settings.luidColumn.name) = COALESCE(excluded.\(Settings.luidColumn.name),
                    \(Settings.databaseTableName).\(Settings.luidColumn.name)),
                \(Settings.macIdColumn.name) = COALESCE(excluded.\(Settings.macIdColumn.name),
                    \(Settings.databaseTableName).\(Settings.macIdColumn.name))
            """, arguments: [
                "id": seed.id,
                "luid": normalizedTag.luid?.value,
                "macId": normalizedTag.macId?.value,
                "description": description,
                "descriptionLastUpdated": descriptionLastUpdated,
            ])

            let request = Settings.filter(Settings.idColumn == seed.id)
            return try request.fetchOne(db)!
        }
    }

    public func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        return try write { db in
            let normalizedTag = try normalizedSensor(ruuviTag, db: db)
            guard let filter = identifierFilter(
                luid: normalizedTag.luid,
                macId: normalizedTag.macId,
                luidColumn: Settings.luidColumn,
                macColumn: Settings.macIdColumn
            ) else { return false }
            let request = Settings.filter(filter)
            guard let sensorSettings = try request.fetchOne(db) else {
                return false
            }
            return try sensorSettings.delete(db)
        }
    }

    public func deleteSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        try write { db in
            let settingsId = SensorSettingsStruct(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                temperatureOffset: nil,
                humidityOffset: nil,
                pressureOffset: nil
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
            return try request.deleteAll(db) > 0
        }
    }

    public func cleanupDBSpace() async throws -> Bool {
        do {
            try await database.dbPool.vacuum()
            return true
        } catch {
            throw mapPersistenceError(error)
        }
    }

    // MARK: - Queued cloud requests

    @discardableResult
    public func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] {
        try read { db in
            try QueuedRequest
                .order(QueuedRequest.requestDateColumn)
                .fetchAll(db)
                .map { $0 }
        }
    }

    @discardableResult
    public func readQueuedRequests(
        for key: String
    ) async throws -> [RuuviCloudQueuedRequest] {
        try await readQueuedRequests().filter { req in
            req.uniqueKey != nil && req.uniqueKey == key
        }
    }

    @discardableResult
    public func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws -> [RuuviCloudQueuedRequest] {
        try await readQueuedRequests().filter { req in
            req.type != nil && req.type == type
        }
    }

    @discardableResult
    public func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws -> Bool {
        let requests = try await readQueuedRequests()
        if let existingRequest = requests.first(
            where: {
                ($0.uniqueKey != nil && $0.uniqueKey == request.uniqueKey)
                && ($0.type != nil && $0.type == request.type)
            }
        ) {
            return try updateQueueRequest(
                newRequest: request,
                existingRequest: existingRequest
            )
        }
        return try insertQueueRequest(request)
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
        return try write { db in
            try entity.delete(db)
        }
    }

    @discardableResult
    public func deleteQueuedRequests() async throws -> Bool {
        try write { db in
            try QueuedRequest.deleteAll(db) > 0
        }
    }

    // MARK: - Subscription

    public func save(
        subscription: CloudSensorSubscription
    ) async throws -> CloudSensorSubscription {
        try write { db in
            try subscription.sqlite.save(db)
            return subscription
        }
    }

    public func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws -> CloudSensorSubscription? {
        try read { db in
            let normalizedTag = try normalizedSensor(ruuviTag, db: db)
            let request = SensorSubscription.filter(
                normalizedTag.macId?.value != nil
                    && SensorSubscription.macIdColumn == normalizedTag.macId?.value
            )
            return try request.fetchOne(db)
        }
    }
}

// MARK: - Private

private extension RuuviPersistenceSQLite {
    func identifierFilter(
        luid: LocalIdentifier?,
        macId: MACIdentifier?,
        luidColumn: Column,
        macColumn: Column
    ) -> SQLExpression? {
        var filter: SQLExpression?
        if let luidValue = luid?.value {
            filter = luidColumn == luidValue
        }
        if let macValue = macId?.value {
            let macFilter = macColumn.like("%\(macValue.lastThreeBytes)")
            filter = filter.map { $0 || macFilter } ?? macFilter
        }
        return filter
    }

    func read<Value>(_ operation: (Database) throws -> Value) throws -> Value {
        do {
            return try database.dbPool.read { db in
                try operation(db)
            }
        } catch {
            throw mapPersistenceError(error)
        }
    }

    func write<Value>(_ operation: (Database) throws -> Value) throws -> Value {
        do {
            return try database.dbPool.write { db in
                try operation(db)
            }
        } catch {
            throw mapPersistenceError(error)
        }
    }

    func mapPersistenceError(_ error: Error) -> RuuviPersistenceError {
        if let persistenceError = error as? RuuviPersistenceError {
            return persistenceError
        }
        if error is RecordError {
            return .failedToFindRuuviTag
        }
        return .grdb(error)
    }

    func insertQueueRequest(_ newRequest: RuuviCloudQueuedRequest) throws -> Bool {
        try write { db in
            assert(newRequest.uniqueKey != nil)
            try newRequest.sqlite.insert(db)
            return true
        }
    }

    func updateQueueRequest(
        newRequest: RuuviCloudQueuedRequest,
        existingRequest: RuuviCloudQueuedRequest
    ) throws -> Bool {
        let retryCount = (existingRequest.attempts ?? 0) + 1
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
        return try write { db in
            try entity.update(db)
            return true
        }
    }

    func normalizedSensor(
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

    func normalizedRecord(
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

    func normalizedMacId(
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

    func fetchCandidateMacsMatchingSuffix(
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

// swiftlint:enable file_length type_body_length
