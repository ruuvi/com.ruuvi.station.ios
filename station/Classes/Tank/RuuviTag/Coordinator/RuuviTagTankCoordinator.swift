import Foundation
import Future

class RuuviTagTankCoordinator: RuuviTagTank {

    var sqlite: RuuviTagPersistenceSQLite!
    var realm: RuuviTagPersistenceRealm!
    var idPersistence: IDPersistence!

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        if let mac = ruuviTag.mac, let uuid = ruuviTag.luid {
            idPersistence.set(mac: mac, for: uuid)
        }
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
        } else if let mac = idPersistence.mac(for: record.ruuviTagId) {
            return sqlite.create(record.with(mac: mac))
        } else {
            return realm.create(record)
        }
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let sqliteRecords = records.filter({ $0.mac != nil })
        let realmRecords = records.filter({ $0.mac == nil })
        let sqliteOperation = sqlite.create(sqliteRecords)
        let realmOpearion = realm.create(realmRecords)
        Future.zip(sqliteOperation, realmOpearion).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let sqliteOperation = sqlite.deleteAllRecords(ruuviTagId)
        let realmOpearion = realm.deleteAllRecords(ruuviTagId)
        Future.zip(sqliteOperation, realmOpearion).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }
}
