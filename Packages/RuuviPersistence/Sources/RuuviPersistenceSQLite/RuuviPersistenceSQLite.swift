#if SWIFT_PACKAGE
    import RuuviContextSQLite
    import RuuviOntologySQLite
    import RuuviPersistence
#endif
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
    typealias UserSetting = RuuviUserSettingSQLite

    public var database: GRDBDatabase {
        context.database
    }

    private let context: SQLiteContext
    public init(context: SQLiteContext) {
        self.context = context
    }

    public func create(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(ruuviTag.macId != nil)
        do {
            try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
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
            outcome = .success(true)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func create(_ record: RuuviTagSensorRecord) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(record.macId != nil)
        do {
            try await database.dbPool.write { db in
                let normalizedRecord = try self.normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.sqlite.insert(db)
            }
            outcome = .success(true)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func createLast(_ record: RuuviTagSensorRecord) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(record.macId != nil)
        do {
            try await database.dbPool.write { db in
                let normalizedRecord = try self.normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.latest.insert(db)
            }
            outcome = .success(true)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func updateLast(_ record: RuuviTagSensorRecord) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(record.macId != nil)
        do {
            try await database.dbPool.write { db in
                let normalizedRecord = try self.normalizedRecord(record, db: db)
                assert(normalizedRecord.macId != nil)
                try normalizedRecord.latest.update(db)
            }
            outcome = .success(true)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func create(_ records: [RuuviTagSensorRecord]) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            try await database.dbPool.write { db in
                for record in records {
                    assert(record.macId != nil)
                    let normalizedRecord = try self.normalizedRecord(record, db: db)
                    assert(normalizedRecord.macId != nil)
                    try normalizedRecord.sqlite.insert(db)
                }
            }
            outcome = .success(true)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func readAll() async throws(RuuviPersistenceError) -> [AnyRuuviTagSensor] {
        var outcome: Result<[AnyRuuviTagSensor], RuuviPersistenceError>
        var sqliteEntities = [RuuviTagSensor]()

        do {
            try await database.dbPool.read { db in
                let request = Entity.order(Entity.versionColumn)
                sqliteEntities = try request.fetchAll(db)
            }
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readOne(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> AnyRuuviTagSensor {
        var outcome: Result<AnyRuuviTagSensor, RuuviPersistenceError>

        var entity: Entity?
        do {
            try await database.dbPool.read { db in
                let request = Entity.filter(Entity.luidColumn == ruuviTagId || Entity.macColumn == ruuviTagId)
                entity = try request.fetchOne(db)
            }
            if let entity {
                outcome = .success(entity.any)
            } else {
                outcome = .failure(.failedToFindRuuviTag)
            }
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readAll(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord] {
        var outcome: Result<[RuuviTagSensorRecord], RuuviPersistenceError>

        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try await database.dbPool.read { db in
                let request = Record.order(Record.dateColumn)
                    .filter(Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                sqliteEntities = try request.fetchAll(db)
            }
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readAll(
        _ ruuviTagId: String,
        after date: Date
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord] {
        var outcome: Result<[RuuviTagSensorRecord], RuuviPersistenceError>
        let lastThree = ruuviTagId.lastThreeBytes

        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try await database.dbPool.read { db in
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
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func read(
        _ ruuviTagId: String,
        after date: Date,
        with interval: TimeInterval
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord] {
        var outcome: Result<[RuuviTagSensorRecord], RuuviPersistenceError>
        let lastThree = ruuviTagId.lastThreeBytes

        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try await database.dbPool.read { db in
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
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readDownsampled(
        _ ruuviTagId: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord] {
        let highDensityDate =
            Calendar.current.date(
                byAdding: .minute,
                value: -intervalMinutes,
                to: Date()
            ) ?? Date()
        let pruningInterval =
            (highDensityDate.timeIntervalSince1970 - date.timeIntervalSince1970) / points

        var outcome: Result<[RuuviTagSensorRecord], RuuviPersistenceError>
        let lastThree = ruuviTagId.lastThreeBytes

        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try await database.dbPool.read { db in
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
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readAll(
        _ ruuviTagId: String,
        with interval: TimeInterval
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord] {
        var outcome: Result<[RuuviTagSensorRecord], RuuviPersistenceError>
        let lastThree = ruuviTagId.lastThreeBytes

        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try await database.dbPool.read { db in
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
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readLast(
        _ ruuviTagId: String,
        from: TimeInterval
    ) async throws(RuuviPersistenceError) -> [RuuviTagSensorRecord] {
        var outcome: Result<[RuuviTagSensorRecord], RuuviPersistenceError>

        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try await database.dbPool.read { db in
                let request = Record.order(Record.dateColumn)
                    .filter(
                        (Record.luidColumn == ruuviTagId || Record.macColumn == ruuviTagId)
                            && Record.dateColumn > Date(timeIntervalSince1970: from))
                sqliteEntities = try request.fetchAll(db)
            }
            outcome = .success(sqliteEntities.map(\.any))
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readLast(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> RuuviTagSensorRecord? {
        var outcome: Result<RuuviTagSensorRecord?, RuuviPersistenceError>

        do {
            var sqliteRecord: Record?
            try await database.dbPool.read { db in
                let request = Record.order(
                    Record.dateColumn.desc
                ).filter(
                    (ruuviTag.luid?.value != nil && Record.luidColumn == ruuviTag.luid?.value)
                        || (ruuviTag.macId?.value != nil
                            && Record.macColumn
                                .like(
                                    "%\(ruuviTag.macId?.value.lastThreeBytes ?? "")"
                                ))
                )
                sqliteRecord = try request.fetchOne(db)
            }
            outcome = .success(sqliteRecord)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readLatest(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> RuuviTagSensorRecord? {
        var outcome: Result<RuuviTagSensorRecord?, RuuviPersistenceError>

        do {
            var sqliteRecord: RecordLatest?
            try await database.dbPool.read { db in
                let request = RecordLatest.order(RecordLatest.dateColumn.desc)
                    .filter(
                        (ruuviTag.luid?.value != nil && RecordLatest.luidColumn == ruuviTag.luid?.value)
                            || (ruuviTag.macId?.value != nil
                                && RecordLatest.macColumn.like(
                                    "%\(ruuviTag.macId?.value.lastThreeBytes ?? "")"
                                ))
                    )
                sqliteRecord = try request.fetchOne(db)
            }
            outcome = .success(sqliteRecord)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func deleteLatest(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            var deletedCount = 0
            let request =
                RecordLatest
                .filter(RecordLatest.luidColumn == ruuviTagId || RecordLatest.macColumn == ruuviTagId)
            try await database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            outcome = .success(deletedCount > 0)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func update(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(ruuviTag.macId != nil)

        do {
            try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
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
            outcome = .success(true)
        } catch let persistenceError as RuuviPersistenceError {
            outcome = .failure(persistenceError)
        } catch let recordError as RecordError {
            if case .recordNotFound = recordError {
                outcome = .failure(.failedToFindRuuviTag)
            } else {
                outcome = .failure(.grdb(recordError))
            }
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func delete(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(ruuviTag.macId != nil)
        do {
            let success = try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
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
                let deleted = try entity.delete(db)
                let settings = Settings.filter(
                    (normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value)
                        || (normalizedTag.macId?.value != nil
                            && Settings.macIdColumn.like(
                                "%\(normalizedTag.macId?.value.lastThreeBytes ?? "")"
                            ))
                )
                if let settings = try settings.fetchOne(db) {
                    try settings.delete(db)
                }
                return deleted
            }
            outcome = .success(success)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func deleteAllRecords(_ ruuviTagId: String) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            var deletedCount = 0
            let request = Record.filter(
                Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
            )
            try await database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            outcome = .success(deletedCount > 0)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func deleteAllRecords(_ ruuviTagId: String, before date: Date) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            var deletedCount = 0
            let request = Record.filter(
                Record.luidColumn == ruuviTagId || Record.macColumn.like("%\(ruuviTagId.lastThreeBytes)")
            ).filter(Record.dateColumn < date)
            try await database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            outcome = .success(deletedCount > 0)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func getStoredTagsCount() async throws(RuuviPersistenceError) -> Int {
        var outcome: Result<Int, RuuviPersistenceError>

        do {
            var count = 0
            try await database.dbPool.read { db in
                count = try Entity.fetchCount(db)
            }
            outcome = .success(count)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func getStoredMeasurementsCount() async throws(RuuviPersistenceError) -> Int {
        var outcome: Result<Int, RuuviPersistenceError>

        do {
            var count = 0
            try await database.dbPool.read { db in
                count = try Record.fetchCount(db)
            }
            outcome = .success(count)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readSensorSettings(_ ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> SensorSettings? {
        var outcome: Result<SensorSettings?, RuuviPersistenceError>
        do {
            var sqliteSensorSettings: Settings?
            try await database.dbPool.read { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
                let request = Settings.filter(
                    (normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value)
                        || (normalizedTag.macId?.value != nil
                            && Settings.macIdColumn.like(
                                "%\(normalizedTag.macId?.value.lastThreeBytes ?? "")"
                            ))
                )
                sqliteSensorSettings = try request.fetchOne(db)
            }
            outcome = .success(sqliteSensorSettings)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func save(
        sensorSettings: SensorSettings
    ) async throws(RuuviPersistenceError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPersistenceError>
        do {
            try await database.dbPool.write { db in
                try sensorSettings.sqlite.save(db)
            }
            outcome = .success(sensorSettings)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    // MARK: - User settings

    public func readUserSettings() async throws(RuuviPersistenceError) -> [RuuviUserSetting] {
        var outcome: Result<[RuuviUserSetting], RuuviPersistenceError>

        var sqliteSettings = [UserSetting]()
        do {
            try await database.dbPool.read { db in
                let request = UserSetting.order(UserSetting.keyColumn)
                sqliteSettings = try request.fetchAll(db)
            }
            outcome = .success(sqliteSettings)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func readUserSetting(
        for key: String
    ) async throws(RuuviPersistenceError) -> RuuviUserSetting? {
        var outcome: Result<RuuviUserSetting?, RuuviPersistenceError>

        var sqliteSetting: UserSetting?
        do {
            try await database.dbPool.read { db in
                let request = UserSetting.filter(UserSetting.keyColumn == key)
                sqliteSetting = try request.fetchOne(db)
            }
            outcome = .success(sqliteSetting)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func save(
        userSetting: RuuviUserSetting
    ) async throws(RuuviPersistenceError) -> RuuviUserSetting {
        var outcome: Result<RuuviUserSetting, RuuviPersistenceError>
        let database = database

        do {
            try await database.dbPool.write { db in
                try userSetting.sqlite.save(db)
            }
            outcome = .success(userSetting)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func save(
        userSettings: [RuuviUserSetting]
    ) async throws(RuuviPersistenceError) -> [RuuviUserSetting] {
        var outcome: Result<[RuuviUserSetting], RuuviPersistenceError>
        let database = database

        do {
            try await database.dbPool.write { db in
                for setting in userSettings {
                    try setting.sqlite.save(db)
                }
            }
            outcome = .success(userSettings)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    public func deleteUserSettings() async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        let database = database

        do {
            var deletedCount = 0
            try await database.dbPool.write { db in
                deletedCount = try UserSetting.deleteAll(db)
            }
            outcome = .success(deletedCount > 0)
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    // swiftlint:disable:next function_body_length
    public func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) async throws(RuuviPersistenceError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPersistenceError>
        assert(ruuviTag.macId != nil)
        do {
            let settings: Settings = try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
                var isAddNewRecord = true
                var sqliteSensorSettings = Settings(
                    luid: normalizedTag.luid,
                    macId: normalizedTag.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
                let request = Settings.filter(
                    (normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value)
                        || (normalizedTag.macId?.value != nil
                            && Settings.macIdColumn.like(
                                "%\(normalizedTag.macId?.value.lastThreeBytes ?? "")"
                            ))
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
                    let normalizedRecord = try self.normalizedRecord(sqliteSensorRecord, db: db)
                    try normalizedRecord.sqlite.insert(db)
                }

                return sqliteSensorSettings
            }

            outcome = .success(settings)
        } catch let e {
            outcome = .failure(.grdb(e))
        }

        return try outcome.get()
    }

    // swiftlint:disable:next function_body_length
    public func updateDisplaySettings(
        for ruuviTag: RuuviTagSensor,
        displayOrder: [String]?,
        defaultDisplayOrder: Bool?,
        displayOrderLastUpdated: Date?,
        defaultDisplayOrderLastUpdated: Date?
    ) async throws(RuuviPersistenceError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPersistenceError>
        do {
            let settings: Settings = try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
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

                try db.execute(
                    sql: """
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
                        """,
                    arguments: [
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
            outcome = .success(settings)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func updateDescription(
        for ruuviTag: RuuviTagSensor,
        description: String?,
        descriptionLastUpdated: Date?
    ) async throws(RuuviPersistenceError) -> SensorSettings {
        var outcome: Result<SensorSettings, RuuviPersistenceError>
        do {
            let settings: Settings = try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
                var seed = Settings(
                    luid: normalizedTag.luid,
                    macId: normalizedTag.macId,
                    temperatureOffset: nil,
                    humidityOffset: nil,
                    pressureOffset: nil
                )
                seed.description = description
                seed.descriptionLastUpdated = descriptionLastUpdated

                try db.execute(
                    sql: """
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
                        """,
                    arguments: [
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
            outcome = .success(settings)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func deleteOffsetCorrection(ruuviTag: RuuviTagSensor) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        assert(ruuviTag.macId != nil)
        do {
            var success = false
            try await database.dbPool.write { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
                let request = Settings.filter(
                    (normalizedTag.luid?.value != nil && Settings.luidColumn == normalizedTag.luid?.value)
                        || (normalizedTag.macId?.value != nil
                            && Settings.macIdColumn.like(
                                "%\(normalizedTag.macId?.value.lastThreeBytes ?? "")"
                            ))
                )
                let sensorSettings: Settings? = try request.fetchOne(db)
                if let notNullSensorSettings = sensorSettings {
                    success = try notNullSensorSettings.delete(db)
                }
            }
            outcome = .success(success)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func deleteSensorSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            let deletedCount = try await database.dbPool.write { db -> Int in
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
            outcome = .success(deletedCount > 0)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func cleanupDBSpace() async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            try await database.dbPool.vacuum()
            outcome = .success(true)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    // MARK: - Queued cloud requests

    @discardableResult
    public func readQueuedRequests()
        async throws(RuuviPersistenceError) -> [RuuviCloudQueuedRequest]
    {
        var outcome: Result<[RuuviCloudQueuedRequest], RuuviPersistenceError>

        var sqliteEntities = [RuuviCloudQueuedRequest]()
        do {
            try await database.dbPool.read { db in
                let request = QueuedRequest.order(QueuedRequest.requestDateColumn)
                sqliteEntities = try request.fetchAll(db)
            }
            outcome = .success(sqliteEntities.map { $0 })
        } catch {
            outcome = .failure(.grdb(error))
        }

        return try outcome.get()
    }

    @discardableResult
    public func readQueuedRequests(
        for key: String
    ) async throws(RuuviPersistenceError) -> [RuuviCloudQueuedRequest] {
        try await readQueuedRequests().filter { $0.uniqueKey == key }
    }

    @discardableResult
    public func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) async throws(RuuviPersistenceError) -> [RuuviCloudQueuedRequest] {
        try await readQueuedRequests().filter { $0.type == type }
    }

    @discardableResult
    public func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws(RuuviPersistenceError) -> Bool {
        do {
            try await database.dbPool.write { db in
                let existing = try QueuedRequest.fetchAll(db).first {
                    $0.uniqueKey != nil && $0.uniqueKey == request.uniqueKey && $0.type != nil
                        && $0.type == request.type
                }
                if let existing {
                    let entity = QueuedRequest(
                        id: existing.id,
                        type: existing.type,
                        status: request.status,
                        uniqueKey: request.uniqueKey,
                        requestDate: request.requestDate,
                        successDate: request.successDate,
                        attempts: (existing.attempts ?? 0) + 1,
                        requestBodyData: request.requestBodyData,
                        additionalData: request.additionalData
                    )
                    try entity.update(db)
                } else {
                    try request.sqlite.insert(db)
                }
            }
            return true
        } catch {
            throw .grdb(error)
        }
    }

    @discardableResult
    public func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
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
            try await database.dbPool.write { db in
                success = try entity.delete(db)
            }
            outcome = .success(success)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    @discardableResult
    public func deleteQueuedRequests() async throws(RuuviPersistenceError) -> Bool {
        var outcome: Result<Bool, RuuviPersistenceError>
        do {
            var deletedCount = 0
            try await database.dbPool.write { db in
                deletedCount = try QueuedRequest.deleteAll(db)
            }
            outcome = .success(deletedCount > 0)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    // MARK: - Subscription
    public func save(
        subscription: CloudSensorSubscription
    ) async throws(RuuviPersistenceError) -> CloudSensorSubscription {
        var outcome: Result<CloudSensorSubscription, RuuviPersistenceError>
        do {
            try await database.dbPool.write { db in
                try subscription.sqlite.save(db)
            }
            outcome = .success(subscription)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }

    public func readSensorSubscriptionSettings(
        _ ruuviTag: RuuviTagSensor
    ) async throws(RuuviPersistenceError) -> CloudSensorSubscription? {
        var outcome: Result<CloudSensorSubscription?, RuuviPersistenceError>
        do {
            var sqliteSensorSettings: CloudSensorSubscription?
            try await database.dbPool.read { db in
                let normalizedTag = try self.normalizedSensor(ruuviTag, db: db)
                let request = SensorSubscription.filter(
                    normalizedTag.macId?.value != nil
                        && SensorSubscription.macIdColumn == normalizedTag.macId?.value
                )
                sqliteSensorSettings = try request.fetchOne(db)
            }
            outcome = .success(sqliteSensorSettings)
        } catch {
            outcome = .failure(.grdb(error))
        }
        return try outcome.get()
    }
}

// MARK: - Private

extension RuuviPersistenceSQLite {

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
                .fetchOne(db)?.macId
        {
            return existing
        }

        if let existingExact = try Entity
            .filter(Entity.macColumn == macId.value)
            .fetchOne(db)?.macId
        {
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
            let likeMatches =
                try Entity
                .filter(Entity.macColumn.like("%\(suffix)"))
                .fetchAll(db)
                .compactMap(\.macId)
                .filter { $0.value.isLast3BytesEqual(to: macId.value) }
            matches.append(contentsOf: likeMatches)
        }

        if matches.isEmpty {
            let allMatches =
                try Entity
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
        self.lastThreeBytes
    }
}

// swiftlint:enable file_length type_body_length
