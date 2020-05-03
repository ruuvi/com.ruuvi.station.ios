import Foundation
import Future

class RuuviTagTrunkCoordinator: RuuviTagTrunk {

    var sqlite: RuuviTagPersistenceSQLite!
    var realm: RuuviTagPersistenceRealm!

    func readAll() -> Future<[RuuviTagSensor], RUError> {
        let promise = Promise<[RuuviTagSensor], RUError>()
        let sqliteOperation = sqlite.read()
        let realmOperation = realm.read()
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }
    
}
