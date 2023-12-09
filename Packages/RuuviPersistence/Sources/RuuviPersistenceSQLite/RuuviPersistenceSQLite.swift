// swiftlint:disable file_length
import BTKit
import Foundation
import Future
import GRDB
import RuuviContext
import RuuviOntology
import RuuviPersistence
#if canImport(FirebaseCrashlytics)
    import FirebaseCrashlytics
#endif
#if canImport(RuuviOntologySQLite)
    import RuuviOntologySQLite
#endif
#if canImport(RuuviContextSQLite)
    import RuuviContextSQLite
#endif

// swiftlint:disable type_body_length
public class RuuviPersistenceSQLite: RuuviPersistence, DatabaseService {
    public typealias Entity = RuuviTagSQLite
    typealias Record = RuuviTagDataSQLite
    typealias RecordLatest = RuuviTagLatestDataSQLite
    typealias Settings = SensorSettingsSQLite
    typealias QueuedRequest = RuuviCloudQueuedRequestSQLite

    public var database: GRDBDatabase {
        context.database
    }

    private let context: SQLiteContext
    private let readQueue: DispatchQueue =
        .init(label: "RuuviTagPersistenceSQLite.readQueue",
              qos: .default)
    public init(context: SQLiteContext) {
        self.context = context
    }

    public func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
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
            sharedTo: ruuviTag.sharedTo
        )
        do {
            try database.dbPool.write { db in
                try entity.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                try record.sqlite.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func createLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                try record.latest.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func updateLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                try record.latest.update(db)
            }
            promise.succeed(value: true)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            try database.dbPool.write { db in
                for record in records {
                    assert(record.macId != nil)
                    try record.sqlite.insert(db)
                }
            }
            promise.succeed(value: true)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
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
                self?.reportToCrashlytics(error: error)
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
                self?.reportToCrashlytics(error: error)
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
                self?.reportToCrashlytics(error: error)
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
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT
                        *
                    FROM  ruuvi_tag_sensor_records rtsr
                    WHERE rtsr.luid = '\(ruuviTagId)' OR rtsr.mac = '\(ruuviTagId)' AND rtsr.date > ?
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [date]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                self?.reportToCrashlytics(error: error)
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
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT
                        *
                    FROM  ruuvi_tag_sensor_records rtsr
                    WHERE rtsr.luid = '\(ruuviTagId)' OR rtsr.mac = '\(ruuviTagId)' AND rtsr.date > ?
                    GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date) ) / \(Int(interval))
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [date]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                self?.reportToCrashlytics(error: error)
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
        let highDensityDate = Calendar.current.date(byAdding: .minute,
                                                    value: -intervalMinutes,
                                                    to: Date()) ?? Date()
        let pruningInterval =
            (highDensityDate.timeIntervalSince1970 - date.timeIntervalSince1970) / points

        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()

        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT
                        *
                    FROM  ruuvi_tag_sensor_records rtsr
                    WHERE rtsr.luid = '\(ruuviTagId)' OR rtsr.mac = '\(ruuviTagId)' AND rtsr.date > ?
                    AND rtsr.date < ?
                    GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date) ) / \(Int(pruningInterval))
                    UNION ALL
                    SELECT * FROM  ruuvi_tag_sensor_records rtsr
                    WHERE rtsr.luid = '\(ruuviTagId)' OR rtsr.mac = '\(ruuviTagId)' AND rtsr.date > ?
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(
                        db,
                        sql: request,
                        arguments: [date, highDensityDate, highDensityDate]
                    )
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                self?.reportToCrashlytics(error: error)
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
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = """
                    SELECT
                        *
                    FROM  ruuvi_tag_sensor_records rtsr
                    WHERE rtsr.luid = '\(ruuviTagId)' OR rtsr.mac = '\(ruuviTagId)'
                    GROUP BY STRFTIME('%s', STRFTIME('%Y-%m-%d %H:%M:%S', rtsr.date) ) / \(Int(interval))
                    ORDER BY date
                    """
                    sqliteEntities = try Record.fetchAll(db, sql: request)
                }
                promise.succeed(value: sqliteEntities.map(\.any))
            } catch {
                self?.reportToCrashlytics(error: error)
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
                self?.reportToCrashlytics(error: error)
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
                    let request = Record.order(Record.dateColumn.desc)
                        .filter(
                            (ruuviTag.luid?.value != nil && Record.luidColumn == ruuviTag.luid?.value)
                                || (ruuviTag.macId?.value != nil && Record.macColumn == ruuviTag.macId?.value))
                    sqliteRecord = try request.fetchOne(db)
                }
                promise.succeed(value: sqliteRecord)
            } catch {
                self?.reportToCrashlytics(error: error)
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
                            (ruuviTag.luid?.value != nil && RecordLatest.luidColumn == ruuviTag.luid?.value)
                                || (ruuviTag.macId?.value != nil && RecordLatest.macColumn == ruuviTag.macId?.value))
                    sqliteRecord = try request.fetchOne(db)
                }
                promise.succeed(value: sqliteRecord)
            } catch {
                self?.reportToCrashlytics(error: error)
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
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
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
            sharedTo: ruuviTag.sharedTo
        )

        do {
            try database.dbPool.write { db in
                try entity.update(db)
            }
            promise.succeed(value: true)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
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
            sharedTo: ruuviTag.sharedTo
        )
        do {
            var success = false
            try database.dbPool.write { db in
                success = try entity.delete(db)
            }
            promise.succeed(value: success)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            var deletedCount = 0
            let request = Record.filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
            try database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        do {
            var deletedCount = 0
            let request = Record.filter(
                Record.luidColumn == ruuviTagId
                    || Record.macColumn == ruuviTagId)
                .filter(Record.dateColumn < date)
            try database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            reportToCrashlytics(error: error)
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
                self?.reportToCrashlytics(error: error)
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
                self?.reportToCrashlytics(error: error)
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
                let request = Settings.filter(
                    (ruuviTag.luid?.value != nil && Settings.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil && Settings.macIdColumn == ruuviTag.macId?.value)
                )
                sqliteSensorSettings = try request.fetchOne(db)
            }
            promise.succeed(value: sqliteSensorSettings)
        } catch {
            reportToCrashlytics(error: error)
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
            var isAddNewRecord = true
            var sqliteSensorSettings = Settings(
                luid: ruuviTag.luid,
                macId: ruuviTag.macId,
                temperatureOffset: nil,
                temperatureOffsetDate: nil,
                humidityOffset: nil,
                humidityOffsetDate: nil,
                pressureOffset: nil,
                pressureOffsetDate: nil
            )
            try database.dbPool.read { db in
                let request = Settings.filter(
                    (ruuviTag.luid?.value != nil && Settings.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil && Settings.macIdColumn == ruuviTag.macId?.value)
                )
                if let existingSettings = try request.fetchOne(db) {
                    sqliteSensorSettings = existingSettings
                    isAddNewRecord = false
                }
            }
            switch type {
            case .humidity:
                sqliteSensorSettings.humidityOffset = value
                sqliteSensorSettings.humidityOffsetDate = value == nil ? nil : Date()
            case .pressure:
                sqliteSensorSettings.pressureOffset = value
                sqliteSensorSettings.pressureOffsetDate = value == nil ? nil : Date()
            default:
                sqliteSensorSettings.temperatureOffset = value
                sqliteSensorSettings.temperatureOffsetDate = value == nil ? nil : Date()
            }
            try database.dbPool.write { db in
                if isAddNewRecord {
                    try sqliteSensorSettings.insert(db)
                } else {
                    try sqliteSensorSettings.update(db)
                }
            }
            if let sqliteSensorRecord = record {
                try database.dbPool.write { db in
                    try sqliteSensorRecord
                        .sqlite.insert(db)
                }
            }
            promise.succeed(value: sqliteSensorSettings)
        } catch let e {
            print(e)
            reportToCrashlytics(error: e)
            promise.fail(error: .grdb(e))
        }

        return promise.future
    }

    public func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        do {
            var success = false
            try database.dbPool.write { db in
                let request = Settings.filter(
                    (ruuviTag.luid?.value != nil && Settings.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil && Settings.macIdColumn == ruuviTag.macId?.value)
                )
                let sensorSettings: Settings? = try request.fetchOne(db)
                if let notNullSensorSettings = sensorSettings {
                    success = try notNullSensorSettings.delete(db)
                }
            }
            promise.succeed(value: success)
        } catch {
            reportToCrashlytics(error: error)
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
        -> Future<[RuuviCloudQueuedRequest], RuuviPersistenceError>
    {
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
                self?.reportToCrashlytics(error: error)
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
            reportToCrashlytics(error: error)
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
}

// MARK: - Private

extension RuuviPersistenceSQLite {
    func reportToCrashlytics(error: Error, method: String = #function, line: Int = #line) {
        #if canImport(FirebaseCrashlytics)
            Crashlytics.crashlytics().log("\(method)(line: \(line)")
            Crashlytics.crashlytics().record(error: error)
        #endif
    }

    /// Create or Update a queued request.
    private func createQueueRequest(
        isCreate: Bool,
        newRequest: RuuviCloudQueuedRequest,
        existingRequest: RuuviCloudQueuedRequest?
    )
        -> Future<Bool, RuuviPersistenceError>
    {
        let promise = Promise<Bool, RuuviPersistenceError>()
        if isCreate {
            do {
                try database.dbPool.write { db in
                    assert(newRequest.uniqueKey != nil)
                    try newRequest.sqlite.insert(db)
                }
                promise.succeed(value: true)
            } catch {
                reportToCrashlytics(error: error)
                promise.fail(error: .grdb(error))
            }
        } else {
            guard let existingRequest else {
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
}

// swiftlint:enable file_length type_body_length
