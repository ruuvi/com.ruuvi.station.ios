import Foundation
import Future

class RuuviTagTankCoordinator: RuuviTagTank {

    var sqlite: RuuviTagPersistenceSQLite!
    var realm: RuuviTagPersistenceRealm!

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        if ruuviTag.mac != nil {
            return sqlite.add(ruuviTag)
        } else {
            return realm.add(ruuviTag)
        }
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        return promise.future
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        return promise.future
    }

    func delete(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        return promise.future
    }

}
