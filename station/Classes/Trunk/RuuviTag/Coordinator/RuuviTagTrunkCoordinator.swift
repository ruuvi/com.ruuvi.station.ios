import Foundation
import Future

class RuuviTagTrunkCoordinator: RuuviTagTrunk {

    var sqlite: RuuviTagPersistence!
    var realm: RuuviTagPersistence!

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RUError> {
        // FIXME: respect realm
        return sqlite.readOne(ruuviTagId)
    }

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        let sqliteOperation = sqlite.readAll(ruuviTagId)
        let realmOperation = realm.readAll(ruuviTagId)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func readAll() -> Future<[RuuviTagSensor], RUError> {
        let promise = Promise<[RuuviTagSensor], RUError>()
        let sqliteOperation = sqlite.readAll()
        let realmOperation = realm.readAll()
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError> {
        if ruuviTag.mac != nil {
            return sqlite.readLast(ruuviTag)
        } else {
            return realm.readLast(ruuviTag)
        }
    }
}
