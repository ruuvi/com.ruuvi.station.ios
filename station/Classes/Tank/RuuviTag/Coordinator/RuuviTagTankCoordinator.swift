import Foundation
import Future

class RuuviTagTankCoordinator: RuuviTagTank {

    var sqlite: RuuviTagPersistenceSQLite!
    var realm: RuuviTagPersistenceRealm!

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        if ruuviTag.mac != nil {
            return sqlite.create(ruuviTag)
        } else {
            return realm.create(ruuviTag)
        }
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        if ruuviTag.mac != nil {
            return sqlite.update(ruuviTag)
        } else {
            return realm.update(ruuviTag)
        }
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        if ruuviTag.mac != nil {
            return sqlite.delete(ruuviTag)
        } else {
            return realm.delete(ruuviTag)
        }
    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        if record.mac != nil {
            return sqlite.create(record)
        } else {
            return realm.create(record)
        }
    }
}
