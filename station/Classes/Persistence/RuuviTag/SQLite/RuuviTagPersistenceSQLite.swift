import BTKit
import Foundation
import Future
import GRDB

class RuuviTagPersistenceSQLite: RuuviTagPersistence, DatabaseService {
    typealias Entity = RuuviTagSQLite
    typealias Record = RuuviTagDataSQLite

    let database: GRDBDatabase

    init(database: GRDBDatabase) {
        self.database = database
    }

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(id: ruuviTag.id,
                            macId: ruuviTag.macId,
                            luid: ruuviTag.luid,
                            name: ruuviTag.name,
                            version: ruuviTag.version,
                            isConnectable: ruuviTag.isConnectable)

        do {
            try database.dbPool.write { db in
                try entity.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(record.macId != nil)
        do {
            try database.dbPool.write { db in
                try record.sqlite.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            try database.dbPool.write { db in
                for record in records {
                    assert(record.macId != nil)
                    try record.sqlite.insert(db)
                }
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func readAll() -> Future<[AnyRuuviTagSensor], RUError> {
        let promise = Promise<[AnyRuuviTagSensor], RUError>()
        var sqliteEntities = [RuuviTagSensor]()
        do {
            try database.dbPool.read { db in
                let request = Entity.order(Entity.versionColumn)
                sqliteEntities = try request.fetchAll(db)
            }
            promise.succeed(value: sqliteEntities.map({ $0.any }))
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RUError> {
        let promise = Promise<AnyRuuviTagSensor, RUError>()
        var entity: Entity?
        do {
            try database.dbPool.read { db in
                let request = Entity.filter(Entity.idColumn == ruuviTagId)
                entity = try request.fetchOne(db)
            }
            if let entity = entity {
                promise.succeed(value: entity.any)
            } else {
                promise.fail(error: .unexpected(.failedToFindRuuviTag))
            }
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        var sqliteEntities = [RuuviTagSensorRecord]()
        do {
            try database.dbPool.read { db in
                let request = Record.order(Record.dateColumn)
                                    .filter(Record.ruuviTagIdColumn == ruuviTagId)
                sqliteEntities = try request.fetchAll(db)
            }
            promise.succeed(value: sqliteEntities.map({ $0.any }))
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError> {
        assert(ruuviTag.macId != nil)
        let promise = Promise<RuuviTagSensorRecord?, RUError>()
        do {
            var sqliteRecord: Record?
            try database.dbPool.read { db in
                let request = Record.order(Record.dateColumn.desc)
                                    .filter(Record.ruuviTagIdColumn == ruuviTag.id)
                sqliteRecord = try request.fetchOne(db)
            }
            promise.succeed(value: sqliteRecord)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(id: ruuviTag.id,
                            macId: ruuviTag.macId,
                            luid: ruuviTag.luid,
                            name: ruuviTag.name,
                            version: ruuviTag.version,
                            isConnectable: ruuviTag.isConnectable)

        do {
            try database.dbPool.write { db in
                try entity.update(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.macId != nil)
        let entity = Entity(id: ruuviTag.id,
                            macId: ruuviTag.macId,
                            luid: ruuviTag.luid,
                            name: ruuviTag.name,
                            version: ruuviTag.version,
                            isConnectable: ruuviTag.isConnectable)

        do {
            var success = false
            try database.dbPool.write { db in
                success = try entity.delete(db)
            }
            promise.succeed(value: success)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            var deletedCount = 0
            let request = Record.filter(Record.ruuviTagIdColumn == ruuviTagId)
            try database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        do {
            var deletedCount = 0
            let request = Record.filter(Record.ruuviTagIdColumn == ruuviTagId).filter(Record.dateColumn < date)
            try database.dbPool.write { db in
                deletedCount = try request.deleteAll(db)
            }
            promise.succeed(value: deletedCount > 0)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
}
