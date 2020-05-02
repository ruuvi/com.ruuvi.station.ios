import BTKit
import Foundation
import Future
import RealmSwift

class RuuviTagPersistenceSQLite: DatabaseService {
    typealias Entity = RuuviTagSQLite
    typealias Record = RuuviTagDataSQLite

    let database: GRDBDatabase

    init(database: GRDBDatabase) {
        self.database = database
    }

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac != nil)
        let entity = Entity(id: ruuviTag.id,
                            mac: ruuviTag.mac,
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
        assert(record.mac != nil)
        let data = RuuviTagDataSQLite(ruuviTagId: record.ruuviTagId,
                                      date: record.date,
                                      mac: record.mac,
                                      rssi: record.rssi,
                                      temperature: record.temperature,
                                      humidity: record.humidity,
                                      pressure: record.pressure,
                                      acceleration: record.acceleration,
                                      voltage: record.voltage,
                                      movementCounter: record.movementCounter,
                                      measurementSequenceNumber: record.measurementSequenceNumber,
                                      txPower: record.txPower)
        do {
            try database.dbPool.write { db in
                try data.insert(db)
            }
            promise.succeed(value: true)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }

    func read() -> Future<[RuuviTagSensor], RUError> {
        let promise = Promise<[RuuviTagSensor], RUError>()
        var sqliteEntities = [RuuviTagSensor]()
        do {
            try database.dbPool.read { db in
                let request = Entity.order(Entity.versionColumn)
                sqliteEntities = try request.fetchAll(db)
            }
            promise.succeed(value: sqliteEntities)
        } catch {
            promise.fail(error: .persistence(error))
        }
        return promise.future
    }
}
