// swiftlint:disable file_length
import BTKit
import Foundation
import Future
import GRDB
import RuuviOntology
import RuuviContext
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics
#endif

// swiftlint:disable type_body_length
class RuuviPersistenceSQLite: RuuviPersistence, DatabaseService {
    typealias Entity = RuuviTagSQLite
    typealias Record = RuuviTagDataSQLite
    typealias Settings = SensorSettingsSQLite

    var database: GRDBDatabase {
        return context.database
    }
    private let context: SQLiteContext
    private let readQueue: DispatchQueue = DispatchQueue(label: "RuuviTagPersistenceSQLite.readQueue")
    init(context: SQLiteContext) {
        self.context = context
    }

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
            name: ruuviTag.name,
            version: ruuviTag.version,
            isConnectable: ruuviTag.isConnectable,
            isClaimed: ruuviTag.isClaimed,
            isOwner: ruuviTag.isOwner,
            owner: ruuviTag.owner
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

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPersistenceError> {
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

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPersistenceError> {
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

    func readAll() -> Future<[AnyRuuviTagSensor], RuuviPersistenceError> {
        let promise = Promise<[AnyRuuviTagSensor], RuuviPersistenceError>()
        var sqliteEntities = [RuuviTagSensor]()
        readQueue.async { [weak self] in
            do {
                try self?.database.dbPool.read { db in
                    let request = Entity.order(Entity.versionColumn)
                    sqliteEntities = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteEntities.map({ $0.any }))
            } catch {
                self?.reportToCrashlytics(error: error)
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviPersistenceError> {
        let promise = Promise<AnyRuuviTagSensor, RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var entity: Entity?
            do {
                try self?.database.dbPool.read { db in
                    let request = Entity.filter(Entity.luidColumn == ruuviTagId || Entity.macColumn == ruuviTagId)
                    entity = try request.fetchOne(db)
                }
                if let entity = entity {
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

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviPersistenceError>()
        readQueue.async { [weak self] in
            var sqliteEntities = [RuuviTagSensorRecord]()
            do {
                try self?.database.dbPool.read { db in
                    let request = Record.order(Record.dateColumn)
                        .filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                    sqliteEntities = try request.fetchAll(db)
                }
                promise.succeed(value: sqliteEntities.map({ $0.any }))
            } catch {
                self?.reportToCrashlytics(error: error)
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    func read(
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
                promise.succeed(value: sqliteEntities.map({ $0.any }))
            } catch {
                self?.reportToCrashlytics(error: error)
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    func readAll(
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
                promise.succeed(value: sqliteEntities.map({ $0.any }))
            } catch {
                self?.reportToCrashlytics(error: error)
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }

    func readLast(_ ruuviTagId: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviPersistenceError> {
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
                promise.succeed(value: sqliteEntities.map({ $0.any }))
            } catch {
                self?.reportToCrashlytics(error: error)
                promise.fail(error: .grdb(error))
            }
        }
        return promise.future
    }
    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviPersistenceError> {
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

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(id: ruuviTag.id,
                            macId: ruuviTag.macId,
                            luid: ruuviTag.luid,
                            name: ruuviTag.name,
                            version: ruuviTag.version,
                            isConnectable: ruuviTag.isConnectable,
                            isClaimed: ruuviTag.isClaimed,
                            isOwner: ruuviTag.isOwner,
                            owner: ruuviTag.owner)

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

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(
            id: ruuviTag.id,
            macId: ruuviTag.macId,
            luid: ruuviTag.luid,
            name: ruuviTag.name,
            version: ruuviTag.version,
            isConnectable: ruuviTag.isConnectable,
            isClaimed: ruuviTag.isClaimed,
            isOwner: ruuviTag.isOwner,
            owner: ruuviTag.owner
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

    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPersistenceError> {
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

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPersistenceError> {
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
    func getStoredTagsCount() -> Future<Int, RuuviPersistenceError> {
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
    func getStoredMeasurementsCount() -> Future<Int, RuuviPersistenceError> {
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

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviPersistenceError> {
        let promise = Promise<SensorSettings?, RuuviPersistenceError>()
        do {
            var sqliteSensorSettings: Settings?
            try self.database.dbPool.read { db in
                let request = Settings.filter(
                    Settings.luidColumn == ruuviTag.luid?.value
                        || Settings.macIdColumn == ruuviTag.macId?.value
                )
                sqliteSensorSettings = try request.fetchOne(db)
            }
            promise.succeed(value: sqliteSensorSettings)
        } catch {
            self.reportToCrashlytics(error: error)
            promise.fail(error: .grdb(error))
        }
        return promise.future
    }

    // swiftlint:disable:next function_body_length
    func updateOffsetCorrection(
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
                    Settings.luidColumn == ruuviTag.luid?.value ||
                    Settings.macIdColumn == ruuviTag.macId?.value
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
                    try sqliteSensorRecord.with(sensorSettings: sqliteSensorSettings)
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

    func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPersistenceError> {
        let promise = Promise<Bool, RuuviPersistenceError>()
        assert(ruuviTag.macId != nil)
        do {
            var success = false
            try database.dbPool.write { db in
                let request = Settings.filter(
                    Settings.luidColumn == ruuviTag.luid?.value
                        || Settings.macIdColumn == ruuviTag.macId?.value
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
}

// MARK: - Private
extension RuuviPersistenceSQLite {
    func reportToCrashlytics(error: Error, method: String = #function, line: Int = #line) {
        #if canImport(FirebaseCrashlytics)
        Crashlytics.crashlytics().log("\(method)(line: \(line)")
        Crashlytics.crashlytics().record(error: error)
        #endif
    }
}
// swiftlint:enable file_length
