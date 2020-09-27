import Foundation
import Future

class RuuviTagTankCoordinator: RuuviTagTank {

    var sqlite: RuuviTagPersistence!
    var realm: RuuviTagPersistence!
    var idPersistence: IDPersistence!
    var settings: Settings!
    var backgroundPersistence: BackgroundPersistence!
    var connectionPersistence: ConnectionPersistence!

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if let macId = ruuviTag.macId,
            let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
        }
        if ruuviTag.macId != nil,
            ruuviTag.macId?.value.isEmpty == false {
            sqlite.create(ruuviTag).on(success: { [weak self] (result) in
                self?.settings.tagsSorting.append(ruuviTag.id)
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: error)
            })
        } else {
            realm.create(ruuviTag).on(success: { [weak self] (result) in
                self?.settings.tagsSorting.append(ruuviTag.id)
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: error)
            })
        }
        return promise.future
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        if ruuviTag.macId != nil {
            return sqlite.update(ruuviTag)
        } else {
            return realm.update(ruuviTag)
        }
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        if ruuviTag.macId != nil {
            sqlite.delete(ruuviTag).on(success: { [weak self] success in
                if let luid = ruuviTag.luid {
                    self?.backgroundPersistence.deleteCustomBackground(for: luid)
                    self?.connectionPersistence.setKeepConnection(false, for: luid)
                } else if let macId = ruuviTag.macId {
                    // FIXME:
//                    self?.backgroundPersistence.deleteCustomBackground(for: macId)
//                    self?.connectionPersistence.setKeepConnection(false, for: macId)
                } else {
                    assertionFailure()
                }
                self?.settings.tagsSorting.removeAll(where: {$0 == ruuviTag.id})
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: error)
            })
        } else {
            realm.delete(ruuviTag).on(success: { [weak self] success in
                if let luid = ruuviTag.luid {
                    self?.backgroundPersistence.deleteCustomBackground(for: luid)
                    self?.connectionPersistence.setKeepConnection(false, for: luid)
                } else if let macId = ruuviTag.macId {
                    // FIXME:
//                    self?.backgroundPersistence.deleteCustomBackground(for: macId)
//                    self?.connectionPersistence.setKeepConnection(false, for: macId)
                } else {
                    assertionFailure()
                }
                self?.settings.tagsSorting.removeAll(where: {$0 == ruuviTag.id})
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: error)
            })
        }
        return promise.future

    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RUError> {
        if record.macId != nil {
            return sqlite.create(record)
        } else if let macId = idPersistence.mac(for: record.ruuviTagId.luid) {
            return sqlite.create(record.with(macId: macId))
        } else {
            return realm.create(record)
        }
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let sqliteRecords = records.filter({ $0.macId != nil })
        let realmRecords = records.filter({ $0.macId == nil })
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

     func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RUError> {
        let promise = Promise<Bool, RUError>()
        let sqliteOperation = sqlite.deleteAllRecords(ruuviTagId, before: date)
        let realmOpearion = realm.deleteAllRecords(ruuviTagId, before: date)
        Future.zip(sqliteOperation, realmOpearion).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }
}
