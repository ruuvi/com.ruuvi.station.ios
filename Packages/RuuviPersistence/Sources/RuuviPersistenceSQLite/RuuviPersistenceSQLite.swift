// swiftlint:disable file_length
import BTKit
import Foundation
import Future
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
    typealias UserSetting = RuuviUserSettingSQLite

    public var database: GRDBDatabase {
        context.database
    }

    private let context: SQLiteContext
    private var lastHistoryPrune = Date.distantPast
    private let readQueue: DispatchQueue =
        .init(
            label: "RuuviTagPersistenceSQLite.readQueue",
            qos: .default
        )
    private let writeQueue: DispatchQueue =
        .init(
            label: "RuuviTagPersistenceSQLite.writeQueue",
            qos: .default
        )
    public init(context: SQLiteContext) {
        self.context = context
    }

    public func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
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
                    sharedToPending: normalizedTag.sharedToPending,
                    maxHistoryDays: normalizedTag.maxHistoryDays,
                    lastUpdated: normalizedTag.lastUpdated
                )
                try entity.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                try pruneHistoryIfNeeded(db)
                guard record.date >= RuuviHistoryRange.retained().start else { return }
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.sqlite.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func createLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.latest.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func updateLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                let normalizedRecord = try normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.latest.update(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            let retained = records.filter { $0.date >= RuuviHistoryRange.retained().start }.sorted { $0.date < $1.date }
            for offset in stride(from: 0, to: retained.count, by: 5000) {
                try database.dbPool.write { db in
                    try pruneHistoryIfNeeded(db)
                    for record in retained[offset..<min(offset + 5000, retained.count)] {
                        let normalized = try normalizedRecord(record, db: db)
                        let id = normalized.macId?.value ?? normalized.luid?.value ?? ""
                        let duplicate = try Record.filter((Record.macColumn == id || Record.luidColumn == id) &&
                            Record.dateColumn > normalized.date.addingTimeInterval(-1.5) &&
                            Record.dateColumn < normalized.date.addingTimeInterval(1.5)).fetchCount(db) > 0
                        if !duplicate { try normalized.sqlite.insert(db) }
                    }
                }
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    // UNION ALL lets SQLite merge two ordered index scans without sorting the entire history.
    // The second arm also finds older records whose MAC changed when the device was canonicalized.
    static let boundedHistorySQL = """
        SELECT * FROM ruuvi_tag_sensor_records WHERE mac = ? AND date >= ? AND date < ?
        UNION ALL
        SELECT * FROM ruuvi_tag_sensor_records WHERE luid = ? AND (mac IS NULL OR mac != ?) AND date >= ? AND date < ?
        ORDER BY date
        """

    public func scanHistory(_ id: String, range: RuuviHistoryRange, cancellation: RuuviHistoryCancellation,
                            consume: @escaping (RuuviTagSensorRecord) -> Void) -> Future<Int, RuuviPersistenceError> {
        let promise = Promise<Int, RuuviPersistenceError>()
        readQueue.async { [self] in
            do {
                let revision = try database.dbPool.read { db -> Int in
                    let sensor = try Entity.filter(Entity.macColumn == id || Entity.luidColumn == id).fetchOne(db)
                    let mac = sensor?.macId?.value ?? id
                    let luid = sensor?.luid?.value ?? id
                    let cursor = try Record.fetchCursor(db, sql: Self.boundedHistorySQL,
                                                       arguments: [mac, range.start, range.end, luid, mac, range.start, range.end])
                    while !cancellation.isCancelled, let record = try cursor.next() { consume(record.any) }
                    return try historyRevision(id, db: db)
                }
                promise.succeed(value: cancellation.isCancelled ? -1 : revision)
            } catch { promise.fail(error: .grdb(error)) }
        }
        return promise.future
    }

    public func historyRevision(_ id: String) -> Future<Int, RuuviPersistenceError> {
        let promise = Promise<Int, RuuviPersistenceError>()
        readQueue.async { [self] in
            do { promise.succeed(value: try database.dbPool.read { try historyRevision(id, db: $0) }) }
            catch { promise.fail(error: .grdb(error)) }
        }
        return promise.future
    }

    private func historyRevision(_ id: String, db: Database) throws -> Int {
        let sensor = try Entity.filter(Entity.macColumn == id || Entity.luidColumn == id).fetchOne(db)
        return try Int.fetchOne(db, sql: "SELECT SUM(revision) FROM history_revision WHERE sensor = ? OR sensor = ?",
                               arguments: [sensor?.macId?.value ?? id, sensor?.luid?.value ?? id]) ?? 0
    }

    private func pruneHistoryIfNeeded(_ db: Database) throws {
        let now = Date()
        guard now.timeIntervalSince(lastHistoryPrune) >= 600 else { return }
        let cutoff = RuuviHistoryRange.retained(now: now).start
        try db.execute(sql: "DELETE FROM ruuvi_tag_sensor_records WHERE date < ?", arguments: [cutoff])
        try db.execute(sql: "DELETE FROM history_coverage WHERE end <= ?", arguments: [cutoff.timeIntervalSince1970])
        try db.execute(sql: "UPDATE history_coverage SET start = ? WHERE start < ?", arguments: [cutoff.timeIntervalSince1970, cutoff.timeIntervalSince1970])
        lastHistoryPrune = now
    }

    public func historyCoverage(_ id: String, scope: String, freshAfter: Date) -> Future<RuuviHistoryCoverage, RuuviPersistenceError> {
        let promise = Promise<RuuviHistoryCoverage, RuuviPersistenceError>()
        readQueue.async { [self] in
            do {
                let coverage = try database.dbPool.read { db -> RuuviHistoryCoverage in
                    let generation = try Int.fetchOne(db, sql: "SELECT generation FROM history_generation WHERE sensor = ?", arguments: [id]) ?? 0
                    let rows = try Row.fetchAll(db, sql: "SELECT start, end FROM history_coverage WHERE sensor = ? AND scope = ? AND fetched >= ?",
                                               arguments: [id, scope, freshAfter.timeIntervalSince1970])
                    return RuuviHistoryCoverage(ranges: rows.map {
                        RuuviHistoryRange(start: Date(timeIntervalSince1970: $0["start"]), end: Date(timeIntervalSince1970: $0["end"]))
                    }, generation: generation)
                }
                promise.succeed(value: coverage)
            } catch { promise.fail(error: .grdb(error)) }
        }
        return promise.future
    }

    public func saveHistoryPage(_ id: String, records: [AnyRuuviTagSensorRecord], range: RuuviHistoryRange,
                                scope: String, generation: Int, cancellation: RuuviHistoryCancellation) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        writeQueue.async { [self] in
            do {
                let saved = try database.dbPool.write { db -> Bool in
                    guard !cancellation.isCancelled else { return false }
                    try pruneHistoryIfNeeded(db)
                    let currentGeneration = try Int.fetchOne(db, sql: "SELECT generation FROM history_generation WHERE sensor = ?", arguments: [id]) ?? 0
                    guard generation == currentGeneration,
                          try Entity.filter(Entity.macColumn == id || Entity.luidColumn == id).fetchCount(db) > 0 else { return false }
                    let retained = range.intersection(.retained())
                    guard !retained.isEmpty else { return true }
                    // Timestamp lookup uses the sensor/date indexes and never materializes existing history.
                    for record in records where retained.contains(record.date) {
                        if cancellation.isCancelled { throw HistoryWriteError.cancelled }
                        guard record.macId?.value == id || record.luid?.value == id else { continue }
                        let exists = try Record.filter((Record.macColumn == id || Record.luidColumn == id) &&
                            Record.dateColumn > record.date.addingTimeInterval(-1.5) &&
                            Record.dateColumn < record.date.addingTimeInterval(1.5)).fetchCount(db) > 0
                        if !exists { try normalizedRecord(record, db: db).sqlite.insert(db) }
                    }
                    let now = Date().timeIntervalSince1970
                    var start = retained.start.timeIntervalSince1970
                    var end = retained.end.timeIntervalSince1970
                    var fetched = now
                    let rows = try Row.fetchAll(db, sql: "SELECT rowid, start, end, fetched FROM history_coverage WHERE sensor = ? AND scope = ? ORDER BY start", arguments: [id, scope])
                    var merged = Set<Int64>()
                    var expanded = true
                    while expanded {
                        expanded = false
                        for row in rows {
                            let key: Int64 = row["rowid"]
                            let a: Double = row["start"], b: Double = row["end"], age: Double = row["fetched"]
                            guard !merged.contains(key), age >= now - 86400, a <= end, b >= start else { continue }
                            start = min(start, a); end = max(end, b); fetched = min(fetched, age)
                            merged.insert(key); expanded = true
                        }
                    }
                    for row in rows {
                        let key: Int64 = row["rowid"]
                        let a: Double = row["start"], b: Double = row["end"], age: Double = row["fetched"]
                        guard merged.contains(key) || (a < end && b > start) else { continue }
                        try db.execute(sql: "DELETE FROM history_coverage WHERE rowid = ?", arguments: [key])
                        if a < start { try db.execute(sql: "INSERT INTO history_coverage VALUES (?, ?, ?, ?, ?)", arguments: [id, scope, a, start, age]) }
                        if b > end { try db.execute(sql: "INSERT INTO history_coverage VALUES (?, ?, ?, ?, ?)", arguments: [id, scope, end, b, age]) }
                    }
                    try db.execute(sql: "INSERT INTO history_coverage VALUES (?, ?, ?, ?, ?)", arguments: [id, scope, start, end, fetched])
                    if cancellation.isCancelled { throw HistoryWriteError.cancelled }
                    return true
                }
                promise.succeed(value: saved)
            } catch HistoryWriteError.cancelled {
                promise.succeed(value: false)
            } catch { promise.fail(error: .grdb(error)) }
        }
        return promise.future
    }

    private enum HistoryWriteError: Error { case cancelled }

    private func invalidateHistory(_ id: String, db: Database) throws {
        try db.execute(sql: "DELETE FROM history_coverage WHERE sensor = ?", arguments: [id])
        try db.execute(sql: "INSERT OR IGNORE INTO history_generation(sensor, generation) VALUES (?, 0)", arguments: [id])
        try db.execute(sql: "UPDATE history_generation SET generation = generation + 1 WHERE sensor = ?", arguments: [id])
    }

    public func readAll() -> Future<[AnyRuuviTagSensor], RuuviPersistenceError> {
        let promise = Promise<[AnyRuuviTagSensor], RuuviPersistenceError>()
        var sqliteEntities = [RuuviTagSensor]()
        readQueue.async { [weak self] in
            do {
                try self?.database.dbPool.read { db in
                    let request = Entity.order(Entity.versionColumn)
                    sqliteEntities = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviPersistenceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var entity: Entity?
            do {
                try self?.database.dbPool.read { db in
                    let request = Entity.filter(Entity.luidColumn == ruuviTagId || Entity.macColumn == ruuviTagId)
                    entity = try request.fetchOne(db)
                }
                if let entity {
                    promise.succeed(value: entity.any)
                } else {
                    promise.fail(error: .failedToFindRuuviTag)
                }
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = Record.order(Record.dateColumn)
                        .filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                    sqliteEntities = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readAll(
        _ ruuviTagId: String,
        after date: Date
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        let lastThree = ruuviTagId.lastThreeBytes
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT *
                    FROM ruuvi_tag_sensor_records rtsr
                    WHERE (rtsr.luid = ? OR rtsr.mac LIKE ?)
                    AND rtsr.date > ?
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [ruuviTagId, "%\(lastThree)", date]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        let lastThree = ruuviTagId.lastThreeBytes
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT *
                    FROM ruuvi_tag_sensor_records rtsr
                    WHERE (rtsr.luid = ? OR rtsr.mac LIKE ?) AND rtsr.date > ?
                    GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / ?
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [ruuviTagId, "%\(lastThree)", date, Int(interval)]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let highDensityDate = Calendar.current.date(
            byAdding: .minute,
            value: -intervalMinutes,
            to: Date()
        ) ?? Date()
        let pruningInterval =
            (highDensityDate.timeIntervalSince1970 - date.timeIntervalSince1970) / points

        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        let lastThree = ruuviTagId.lastThreeBytes

        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
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
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [
                            ruuviTagId, "%\(lastThree)", date, highDensityDate, Int(pruningInterval),
                            ruuviTagId, "%\(lastThree)", highDensityDate,
                        ]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        let lastThree = ruuviTagId.lastThreeBytes
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT *
                    FROM ruuvi_tag_sensor_records rtsr
                    WHERE rtsr.luid = ? OR rtsr.mac LIKE ?
                    GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date)) / ?
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [ruuviTagId, "%\(lastThree)", Int(interval)]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readLast(
        _ ruuviTagId: String,
        from: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = Record.order(Record.dateColumn)
                        .filter((Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                            && Record.dateColumn > Date(timeIntervalSince1970: from))
                    sqliteEntities = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviPersistenceError> {
        let promise = Promise<RuuviTagSensorRecord?, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            do {
                var sqliteRecord: Record?
                try self?.database.dbPool.read { db in
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
                    sqliteRecord = try request.fetchOne(db)
                }
                promise.succeed(value: sqliteRecord)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readLatest(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviPersistenceError> {
        let promise = Promise<RuuviTagSensorRecord?, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            do {
                var sqliteRecord: RecordLatest?
                try self?.database.dbPool.read { db in
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
                    sqliteRecord = try request.fetchOne(db)
                }
                promise.succeed(value: sqliteRecord)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func deleteLatest(_ ruuviTagId: String) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            var deletedCount = 0
            let request = RecordLatest
                .filter(RecordLatest.luidColumn == ruuviTagId || RecordLatest.macColumn == ruuviTagId)
            try database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
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
                    sharedToPending: normalizedTag.sharedToPending,
                    maxHistoryDays: normalizedTag.maxHistoryDays,
                    lastUpdated: normalizedTag.lastUpdated
                )
                try entity.update(db)
            }
            promise.succeed(value: true)
        } catch let persistenceError as RuuviPersistenceError {
            promise.fail(error: persistenceError)
        } catch let recordError as RecordError {
            if case .recordNotFound = recordError {
                promise.fail(error: .failedToFindRuuviTag)
            } else {
                promise.fail(error: .grdb(recordError))
            }
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
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
                    sharedToPending: normalizedTag.sharedToPending,
                    maxHistoryDays: normalizedTag.maxHistoryDays
                )
                try invalidateHistory(ruuviTag.id, db: db)
                let success = try entity.delete(db)
                promise.succeed(value: success)
            }
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            var deletedCount = 0
            let request = Record.filter(
                Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
            )
            try database.dbPool.write { db in
                try invalidateHistory(ruuviTagId, db: db)
                deletedCount = try request.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            var deletedCount = 0
            let request = Record.filter(
                Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
            ).filter(Record.dateColumn < date)
            try database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
                try db.execute(sql: "DELETE FROM history_coverage WHERE sensor = ? AND end <= ?", arguments: [ruuviTagId, date.timeIntervalSince1970])
                try db.execute(sql: "UPDATE history_coverage SET start = ? WHERE sensor = ? AND start < ?", arguments: [date.timeIntervalSince1970, ruuviTagId, date.timeIntervalSince1970])
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func getStoredTagsCount() -> Future<Int, RuuviPersistenceError> {
        let promise = Promise<Int, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            do {
                var count = 0
                try self?.database.dbPool.read { db in
                    count = try Entity.fetchCount(db)
                }
                promise.succeed(value: count)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func getStoredMeasurementsCount() -> Future<Int, RuuviPersistenceError> {
        let promise = Promise<Int, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            do {
                var count = 0
                try self?.database.dbPool.read { db in
                    count = try Record.fetchCount(db)
                }
                promise.succeed(value: count)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviPersistenceError> {
        let promise = Promise<SensorSettings?, RuuviPersistenceError>()
        do {
            var sqliteSensorSettings: Settings?
            try database.dbPool.read { db in
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
                sqliteSensorSettings = try request.fetchOne(db)
            }
            promise.succeed(value: sqliteSensorSettings)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func save(
        sensorSettings: SensorSettings
    ) -> Future<SensorSettings, RuuviPersistenceError> {
        let promise = Promise<SensorSettings, RuuviPersistenceError>()
        do {
            try database.dbPool.write { db in
                try sensorSettings.sqlite.save(db)
            }
            promise.succeed(value: sensorSettings)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    // MARK: - User settings

    public func readUserSettings() -> Future<[RuuviUserSetting], RuuviPersistenceError> {
        let promise = Promise<[RuuviUserSetting], RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var sqliteSettings = [UserSetting]()
            do {
                try self?.database.dbPool.read { db in
                    let request = UserSetting.order(UserSetting.keyColumn)
                    sqliteSettings = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteSettings)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func readUserSetting(
        for key: String
    ) -> Future<RuuviUserSetting?, RuuviPersistenceError> {
        let promise = Promise<RuuviUserSetting?, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var sqliteSetting: UserSetting?
            do {
                try self?.database.dbPool.read { db in
                    let request = UserSetting.filter(UserSetting.keyColumn == key)
                    sqliteSetting = try request.fetchOne(db)
                }
                promise.succeed(value: sqliteSetting)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func save(
        userSetting: RuuviUserSetting
    ) -> Future<RuuviUserSetting, RuuviPersistenceError> {
        let promise = Promise<RuuviUserSetting, RuuviPersistenceError>()
        let database = database
        writeQueue.async {
            do {
                try database.dbPool.write { db in
                    try userSetting.sqlite.save(db)
                }
                promise.succeed(value: userSetting)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func save(
        userSettings: [RuuviUserSetting]
    ) -> Future<[RuuviUserSetting], RuuviPersistenceError> {
        let promise = Promise<[RuuviUserSetting], RuuviPersistenceError>()
        let database = database
        writeQueue.async {
            do {
                try database.dbPool.write { db in
                    for setting in userSettings {
                        try setting.sqlite.save(db)
                    }
                }
                promise.succeed(value: userSettings)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    public func deleteUserSettings() -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        let database = database
        writeQueue.async {
            do {
                var deletedCount = 0
                try database.dbPool.write { db in
                    deletedCount = try UserSetting.deleteAll(db)
                }
                promise.succeed(value: deletedCount > 0)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    // swiftlint:disable:next function_body_length
    public func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviPersistenceError> {
        let promise = Promise<SensorSettings, RuuviPersistenceError>()
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

            promise.succeed(value: settings)
        } catch let e {
            promise.fail(error: .grdb(e))
        }

        return promise.future
    }

    // swiftlint:disable:next function_body_length
    public func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) -> Future<SensorSettings, RuuviPersistenceError> {
        let promise = Promise<SensorSettings, RuuviPersistenceError>()
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
                if let updated = try request.fetchOne(db) {
                    return updated
                } else {
                    return seed
                }
            }
            promise.succeed(value: settings)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) -> Future<SensorSettings, RuuviPersistenceError> {
        let promise = Promise<SensorSettings, RuuviPersistenceError>()
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
                if let updated = try request.fetchOne(db) {
                    return updated
                } else {
                    return seed
                }
            }
            promise.succeed(value: settings)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        do {
            var success = false
            try database.dbPool.write { db in
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
                    success = try notNullSensorSettings.delete(db)
                }
            }
            promise.succeed(value: success)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func deleteSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
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
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func cleanupDBSpace() -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            try database.dbPool.vacuum()
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    // MARK: - Queued cloud requests

    @discardableResult
    public func readQueuedRequests()
    -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError> {
        let promise = Promise<[RuuviCloudQueuedRequest], RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviCloudQueuedRequest]()
            do {
                try self?.database.dbPool.read { db in
                    let request = QueuedRequest.order(QueuedRequest.requestDateColumn)
                    sqliteEntities = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteEntities.map { $0 })
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    @discardableResult
    public func readQueuedRequests(
        for key: String
    ) -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError> {
        let promise = Promise<[RuuviCloudQueuedRequest], RuuviPersistenceError>()
        readQueuedRequests().on(success: { reqs in
            let requests = reqs.filter { req in
                req.uniqueKey != nil && req.uniqueKey == key
            }
            promise.succeed(value: requests)
        }, failure: { error in
            promise.fail(error: .grdb(error))
        })
        return promise.future
    }

    @discardableResult
    public func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError> {
        let promise = Promise<[RuuviCloudQueuedRequest], RuuviPersistenceError>()
        readQueuedRequests().on(success: { reqs in
            let requests = reqs.filter { req in
                req.type != nil && req.type == type
            }
            promise.succeed(value: requests)
        }, failure: { error in
            promise.fail(error: .grdb(error))
        })
        return promise.future
    }

    @discardableResult
    public func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        // Check if there's already a request stored for the key.
        // If exists update the existing record, otherwise create a new.
        readQueuedRequests().on(success: { [weak self] requests in

            let existingRequest = requests.first(
                where: { ($0.uniqueKey != nil && $0.uniqueKey == request.uniqueKey)
                    && ($0.type != nil && $0.type == request.type)
                }
            )
            let isCreate = (requests.count == 0) || existingRequest == nil

            self?.createQueueRequest(
                isCreate: isCreate,
                newRequest: request,
                existingRequest: existingRequest
            )
            .on(success: { _ in
                promise.succeed(value: true)
            }, failure: { error in
                promise.fail(error: .grdb(error))
            })
        })
        return promise.future
    }

    @discardableResult
    public func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
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
            var success = false
            try database.dbPool.write { db in
                success = try entity.delete(db)
            }
            promise.succeed(value: success)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    @discardableResult
    public func deleteQueuedRequests() -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            var deletedCount = 0
            try database.dbPool.write { db in
                deletedCount = try QueuedRequest.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    // MARK: - Subscription
    public func save(
        subscription: CloudSensorSubscription
    ) -> Future<CloudSensorSubscription, RuuviPersistenceError> {
        let promise = Promise<CloudSensorSubscription, RuuviPersistenceError>()
        do {
            try database.dbPool.write { db in
                try subscription.sqlite.save(db)
            }
            promise.succeed(value: subscription)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) -> Future<CloudSensorSubscription?, RuuviPersistenceError> {
        let promise = Promise<CloudSensorSubscription?, RuuviPersistenceError>()
        do {
            var sqliteSensorSettings: CloudSensorSubscription?
            try database.dbPool.read { db in
                let normalizedTag = try normalizedSensor(ruuviTag, db: db)
                let request = SensorSubscription.filter(
                    normalizedTag.macId?.value != nil
                    && SensorSubscription.macIdColumn == normalizedTag.macId?.value
                )
                sqliteSensorSettings = try request.fetchOne(db)
            }
            promise.succeed(value: sqliteSensorSettings)
        } catch {
            promise.fail(error: .grdb(error))
        }
        return promise.future
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
    -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        if isCreate {
            do {
                try database.dbPool.write { db in
                    assert(newRequest.uniqueKey != nil)
                    try newRequest.sqlite.insert(db)
                }
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .grdb(error))
            }
        } else {
            guard let existingRequest
            else {
                return promise.future
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
                promise.succeed(value: true)
            } catch {
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
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
