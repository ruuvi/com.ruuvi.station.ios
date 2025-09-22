// swiftlint:disable file_length
import BTKit
import Foundation
import GRDB
import RuuviContext
import RuuviOntology

// swiftlint:disable type_body_length
public class RuuviPersistenceSQLite: RuuviPersistence, DatabaseService {
    public typealias Entity = RuuviTagSQLite
    typealias Record = RuuviTagDataSQLite
    typealias RecordLatest = RuuviTagLatestDataSQLite
    typealias Settings = SensorSettingsSQLite
    typealias QueuedRequest = RuuviCloudQueuedRequestSQLite
    typealias SensorSubscription = RuuviCloudSensorSubscriptionSQLite

    public var database: GRDBDatabase {
        context.database
    }

    private let context: SQLiteContext
    private let readQueue: DispatchQueue =
        .init(
            label: "RuuviTagPersistenceSQLite.readQueue",
            qos: .default
        )
    public init(context: SQLiteContext) {
        self.context = context
    }

    public func create(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
            serviceUUID: ruuviTag.serviceUUID,
            name: ruuviTag.name,
            version: ruuviTag.version,
            firmwareVersion: ruuviTag.firmwareVersion,
            isConnectable: ruuviTag.isConnectable,
            isClaimed: ruuviTag.isClaimed,
            isOwner: ruuviTag.isOwner,
            owner: ruuviTag.owner,
            ownersPlan: ruuviTag.ownersPlan,
            isCloudSensor: ruuviTag.isCloudSensor,
            canShare: ruuviTag.canShare,
            sharedTo: ruuviTag.sharedTo,
            maxHistoryDays: ruuviTag.maxHistoryDays
        )
        do {
            return try await dbWrite { db in
                try entity.insert(db)
                return true
            }
        } catch {
            throw RuuviPersistenceError.grdb(error)
        }
    }

    public func create(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        do {
            return try await dbWrite { db in
                try record.sqlite.insert(db)
                return true
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func createLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        do {
            return try await dbWrite { db in
                try record.latest.insert(db)
                return true
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func updateLast(_ record: RuuviTagSensorRecord) async throws -> Bool {
        assert(record.macId != nil)
        do {
            return try await dbWrite { db in
                try record.latest.update(db)
                return true
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func create(_ records: [RuuviTagSensorRecord]) async throws -> Bool {
        do {
            return try await dbWrite { db in
                for record in records {
                    assert(record.macId != nil)
                    try record.sqlite.insert(db)
                }
                return true
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readAll() async throws -> [AnyRuuviTagSensor] {
        do {
            return try await dbRead { db in
                let request = Entity.order(Entity.versionColumn)
                let rows = try request.fetchAll(db)
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readOne(_ ruuviTagId: String) async throws -> AnyRuuviTagSensor {
        do {
            return try await dbRead { db in
                let request = Entity.filter(Entity.luidColumn == ruuviTagId || Entity.macColumn == ruuviTagId)
                if let entity = try request.fetchOne(db) { return entity.any }
                throw RuuviPersistenceError.failedToFindRuuviTag
            }
        } catch let e as RuuviPersistenceError { throw e } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readAll(_ ruuviTagId: String) async throws -> [RuuviTagSensorRecord] {
        do {
            return try await dbRead { db in
                let request = Record.order(Record.dateColumn)
                    .filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                let rows = try request.fetchAll(db)
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readAll(
        _ ruuviTagId: String,
        after date: Date
    ) async throws -> [RuuviTagSensorRecord] {
        do {
            return try await dbRead { db in
                let sql = """
                SELECT * FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac = ?) AND rtsr.date > ?
                ORDER BY date
                """
                let rows = try Record.fetchAll(db, sql: sql, arguments: [ruuviTagId, ruuviTagId, date])
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        do {
            return try await dbRead { db in
                let sql = """
                SELECT * FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac = ?) AND rtsr.date > ?
                GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / \(Int(interval))
                ORDER BY date
                """
                let rows = try Record.fetchAll(db, sql: sql, arguments: [ruuviTagId, ruuviTagId, date])
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws -> [RuuviTagSensorRecord] {
        let highDensityDate = Calendar.current.date(byAdding: .minute, value: -intervalMinutes, to: Date()) ?? Date()
        let pruningInterval = (highDensityDate.timeIntervalSince1970 - date.timeIntervalSince1970) / points
        do {
            return try await dbRead { db in
                let sql = """
                SELECT * FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac = ?) AND rtsr.date > ? AND rtsr.date < ?
                GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / \(Int(pruningInterval))
                UNION ALL
                SELECT * FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac = ?) AND rtsr.date > ?
                ORDER BY date
                """
                let rows = try Record.fetchAll(db, sql: sql, arguments: [ruuviTagId, ruuviTagId, date, highDensityDate, ruuviTagId, ruuviTagId, highDensityDate])
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        do {
            return try await dbRead { db in
                let sql = """
                SELECT * FROM ruuvi_tag_sensor_records rtsr
                WHERE (rtsr.luid = ? OR rtsr.mac = ?)
                GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / \(Int(interval))
                ORDER BY date
                """
                let rows = try Record.fetchAll(db, sql: sql, arguments: [ruuviTagId, ruuviTagId])
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readLast(
        _ ruuviTagId: String,
        from: TimeInterval
    ) async throws -> [RuuviTagSensorRecord] {
        do {
            return try await dbRead { db in
                let request = Record.order(Record.dateColumn)
                    .filter((Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                        && Record.dateColumn > Date(timeIntervalSince1970: from))
                let rows = try request.fetchAll(db)
                return rows.map(\.any)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readLast(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        do {
            return try await dbRead { db in
                let request = Record.order(Record.dateColumn.desc)
                    .filter(
                        (ruuviTag.luid?.value != nil && Record.luidColumn == ruuviTag.luid?.value)
                            || (ruuviTag.macId?.value != nil && Record.macColumn == ruuviTag.macId?.value))
                return try request.fetchOne(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readLatest(_ ruuviTag: RuuviTagSensor) async throws -> RuuviTagSensorRecord? {
        do {
            return try await dbRead { db in
                let request = RecordLatest.order(RecordLatest.dateColumn.desc)
                    .filter(
                        (ruuviTag.luid?.value != nil && RecordLatest.luidColumn == ruuviTag.luid?.value)
                            || (ruuviTag.macId?.value != nil && RecordLatest.macColumn == ruuviTag.macId?.value))
                return try request.fetchOne(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func deleteLatest(_ ruuviTagId: String) async throws -> Bool {
        do {
            return try await dbWrite { db in
                let request = RecordLatest.filter(RecordLatest.luidColumn == ruuviTagId || RecordLatest.macColumn == ruuviTagId)
                let deletedCount = try request.deleteAll(db)
                return deletedCount > 0
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func update(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
            serviceUUID: ruuviTag.serviceUUID,
            name: ruuviTag.name,
            version: ruuviTag.version,
            firmwareVersion: ruuviTag.firmwareVersion,
            isConnectable: ruuviTag.isConnectable,
            isClaimed: ruuviTag.isClaimed,
            isOwner: ruuviTag.isOwner,
            owner: ruuviTag.owner,
            ownersPlan: ruuviTag.ownersPlan,
            isCloudSensor: ruuviTag.isCloudSensor,
            canShare: ruuviTag.canShare,
            sharedTo: ruuviTag.sharedTo,
            maxHistoryDays: ruuviTag.maxHistoryDays
        )
        do {
            return try await dbWrite { db in
                try entity.update(db)
                return true
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func delete(_ ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
            serviceUUID: ruuviTag.serviceUUID,
            name: ruuviTag.name,
            version: ruuviTag.version,
            firmwareVersion: ruuviTag.firmwareVersion,
            isConnectable: ruuviTag.isConnectable,
            isClaimed: ruuviTag.isClaimed,
            isOwner: ruuviTag.isOwner,
            owner: ruuviTag.owner,
            ownersPlan: ruuviTag.ownersPlan,
            isCloudSensor: ruuviTag.isCloudSensor,
            canShare: ruuviTag.canShare,
            sharedTo: ruuviTag.sharedTo,
            maxHistoryDays: ruuviTag.maxHistoryDays
        )
        do {
            return try await dbWrite { db in
                try entity.delete(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func deleteAllRecords(_ ruuviTagId: String) async throws -> Bool {
        do {
            return try await dbWrite { db in
                let request = Record.filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                let deletedCount = try request.deleteAll(db)
                return deletedCount > 0
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws -> Bool {
        do {
            return try await dbWrite { db in
                let request = Record.filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                    .filter(Record.dateColumn < date)
                let deletedCount = try request.deleteAll(db)
                return deletedCount > 0
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func getStoredTagsCount() async throws -> Int {
        do { return try await dbRead { db in try Entity.fetchCount(db) } } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func getStoredMeasurementsCount() async throws -> Int {
        do { return try await dbRead { db in try Record.fetchCount(db) } } catch { throw RuuviPersistenceError.grdb(error) }
    }

    // MARK: - Async DB helpers
    private func dbWrite<T>(_ block: @escaping (Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            do {
                try database.dbPool.write { db in
                    let result = try block(db)
                    continuation.resume(returning: result)
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func dbRead<T>(_ block: @escaping (Database) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            readQueue.async { [weak self] in
                guard let self else { return }
                do {
                    var value: T!
                    try self.database.dbPool.read { db in
                        value = try block(db)
                    }
                    continuation.resume(returning: value)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    public func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws -> SensorSettings? {
        do {
            return try await dbRead { db in
                let request = Settings.filter(
                    (ruuviTag.luid?.value != nil && Settings.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil && Settings.macIdColumn == ruuviTag.macId?.value)
                )
                return try request.fetchOne(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func save(sensorSettings: SensorSettings) async throws -> SensorSettings {
        do {
            return try await dbWrite { db in
                try sensorSettings.sqlite.save(db)
                return sensorSettings
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws -> SensorSettings {
        assert(ruuviTag.macId != nil)
        do {
            return try await dbWrite { db in
                var isAddNewRecord = true
                var sqliteSensorSettings = Settings(
                    luid: ruuviTag.luid,
                    macId: ruuviTag.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
                let request = Settings.filter(
                    (ruuviTag.luid?.value != nil && Settings.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil && Settings.macIdColumn == ruuviTag.macId?.value)
                )
                if let existing = try request.fetchOne(db) {
                    sqliteSensorSettings = existing
                    isAddNewRecord = false
                }
                switch type {
                case .humidity: sqliteSensorSettings.humidityOffset = value
                case .pressure: sqliteSensorSettings.pressureOffset = value
                default: sqliteSensorSettings.temperatureOffset = value
                }
                if isAddNewRecord { try sqliteSensorSettings.insert(db) } else { try sqliteSensorSettings.update(db) }
                if let r = record { try r.sqlite.insert(db) }
                return sqliteSensorSettings
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws -> Bool {
        assert(ruuviTag.macId != nil)
        do {
            return try await dbWrite { db in
                let request = Settings.filter(
                    (ruuviTag.luid?.value != nil && Settings.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil && Settings.macIdColumn == ruuviTag.macId?.value)
                )
                if let existing = try request.fetchOne(db) {
                    return try existing.delete(db)
                }
                return false
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func cleanupDBSpace() async throws -> Bool {
        do {
            try await database.dbPool.vacuum()
            return true
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    // MARK: - Queued cloud requests

    @discardableResult
    public func readQueuedRequests() async throws -> [RuuviCloudQueuedRequest] {
        do {
            return try await dbRead { db in
                let request = QueuedRequest.order(QueuedRequest.requestDateColumn)
                return try request.fetchAll(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    @discardableResult
    public func readQueuedRequests(for key: String) async throws -> [RuuviCloudQueuedRequest] {
        let all = try await readQueuedRequests()
        return all.filter { $0.uniqueKey != nil && $0.uniqueKey == key }
    }

    @discardableResult
    public func readQueuedRequests(for type: RuuviCloudQueuedRequestType) async throws -> [RuuviCloudQueuedRequest] {
        let all = try await readQueuedRequests()
        return all.filter { $0.type != nil && $0.type == type }
    }

    @discardableResult
    public func createQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
        // Read existing matching request
        let all = try await readQueuedRequests()
        let existing = all.first { ($0.uniqueKey != nil && $0.uniqueKey == request.uniqueKey) && ($0.type != nil && $0.type == request.type) }
        let isCreate = existing == nil
        do {
            return try await dbWrite { db in
                if isCreate {
                    assert(request.uniqueKey != nil)
                    try request.sqlite.insert(db)
                } else if let existing {
                    let retryCount = (existing.attempts ?? 0) + 1
                    let entity = QueuedRequest(
                        id: existing.id,
                        type: existing.type,
                        status: request.status,
                        uniqueKey: request.uniqueKey,
                        requestDate: request.requestDate,
                        successDate: request.successDate,
                        attempts: retryCount,
                        requestBodyData: request.requestBodyData,
                        additionalData: request.additionalData
                    )
                    try entity.update(db)
                }
                return true
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    @discardableResult
    public func deleteQueuedRequest(_ request: RuuviCloudQueuedRequest) async throws -> Bool {
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
            return try await dbWrite { db in
                try entity.delete(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    @discardableResult
    public func deleteQueuedRequests() async throws -> Bool {
        do {
            return try await dbWrite { db in
                let deleted = try QueuedRequest.deleteAll(db)
                return deleted > 0
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    // MARK: - Subscription
    public func save(subscription: CloudSensorSubscription) async throws -> CloudSensorSubscription {
        do {
            return try await dbWrite { db in
                try subscription.sqlite.save(db)
                return subscription
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }

    public func readSensorSubscriptionSettings(_ ruuviTag: RuuviTagSensor) async throws -> CloudSensorSubscription? {
        do {
            return try await dbRead { db in
                let request = SensorSubscription.filter(
                    ruuviTag.macId?.value != nil && SensorSubscription.macIdColumn == ruuviTag.macId?.value
                )
                return try request.fetchOne(db)
            }
        } catch { throw RuuviPersistenceError.grdb(error) }
    }
}

// MARK: - Private

extension RuuviPersistenceSQLite { }

// swiftlint:enable file_length type_body_length
