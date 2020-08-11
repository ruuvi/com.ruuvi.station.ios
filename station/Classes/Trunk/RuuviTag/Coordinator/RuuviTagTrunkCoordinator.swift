import Foundation
import Future

class RuuviTagTrunkCoordinator: RuuviTagTrunk {

    var sqlite: RuuviTagPersistence!
    var realm: RuuviTagPersistence!
    var settings: Settings!

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
        Future.zip(sqliteOperation, realmOperation)
            .on(success: { [weak self] sqliteEntities, realmEntities in
            let combinedValues = sqliteEntities + realmEntities
            if let strongSelf = self {
                promise.succeed(value: strongSelf.reorder(combinedValues))
            } else {
                promise.succeed(value: combinedValues)
            }
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func readAll(_ id: String, with interval: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        let sqliteOperation = sqlite.readAll(id, with: interval)
        let realmOperation = realm.readAll(id, with: interval)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func readLast(_ id: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RUError> {
        let promise = Promise<[RuuviTagSensorRecord], RUError>()
        let sqliteOperation = sqlite.readLast(id, from: from)
        let realmOperation = realm.readLast(id, from: from)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RUError> {
        if ruuviTag.macId != nil {
            return sqlite.readLast(ruuviTag)
        } else {
            return realm.readLast(ruuviTag)
        }
    }
}

extension RuuviTagTrunkCoordinator {
    private func reorder(_ sensors: [RuuviTagSensor]) -> [RuuviTagSensor] {
        let anySensors = sensors.map({$0.any})
        if settings.tagsSorting.isEmpty {
            settings.tagsSorting = sensors.map({$0.id})
            return sensors
        } else {
            return anySensors.reorder(by: settings.tagsSorting).map({$0.struct})
        }
    }
}
