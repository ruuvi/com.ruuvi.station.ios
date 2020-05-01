import BTKit
import Foundation
import Future
import RealmSwift

class RuuviTagPersistenceSQLite: DatabaseService {
    typealias Entity = RuuviTagSQLite
    let database: GRDBDatabase

    init(database: GRDBDatabase) {
        self.database = database
    }

    func add(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        assert(ruuviTag.mac != nil)
        let entity = Entity(id: ruuviTag.id,
                            mac: ruuviTag.mac,
                            uuid: ruuviTag.uuid,
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
}
