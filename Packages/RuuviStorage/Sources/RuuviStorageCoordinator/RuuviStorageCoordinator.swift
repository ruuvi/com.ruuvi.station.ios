import Foundation
import RuuviOntology
import Future
import RuuviPersistence

final class RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviPersistence
    private let realm: RuuviPersistence

    init(sqlite: RuuviPersistence, realm: RuuviPersistence) {
        self.sqlite = sqlite
        self.realm = realm
    }

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviStorageError> {
        // TODO: @rinat respect realm
        let promise = Promise<AnyRuuviTagSensor, RuuviStorageError>()
        sqlite.readOne(ruuviTagId).on(success: { sensor in
            promise.succeed(value: sensor)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll(ruuviTagId)
        let realmOperation = realm.readAll(ruuviTagId)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readAll() -> Future<[AnyRuuviTagSensor], RuuviStorageError> {
        let promise = Promise<[AnyRuuviTagSensor], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll()
        let realmOperation = realm.readAll()
        Future.zip(sqliteOperation, realmOperation)
            .on(success: { sqliteEntities, realmEntities in
            let combinedValues = sqliteEntities + realmEntities
                promise.succeed(value: combinedValues.map({ $0.any }))
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func read(
        _ id: String,
        after date: Date,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.read(id, after: date, with: interval)
        let realmOperation = realm.read(id, after: date, with: interval)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readAll(
        _ id: String,
        with interval: TimeInterval
    ) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll(id, with: interval)
        let realmOperation = realm.readAll(id, with: interval)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readLast(_ id: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readLast(id, from: from)
        let realmOperation = realm.readLast(id, from: from)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviStorageError> {
        let promise = Promise<RuuviTagSensorRecord?, RuuviStorageError>()
        if ruuviTag.macId != nil {
            sqlite.readLast(ruuviTag).on(success: { record in
                promise.succeed(value: record)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.readLast(ruuviTag).on(success: { record in
                promise.succeed(value: record)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        return promise.future
    }

    func getStoredTagsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let sqliteOperation = sqlite.getStoredTagsCount()
        let realmOperation = realm.getStoredTagsCount()
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func getStoredMeasurementsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let sqliteOperation = sqlite.getStoredMeasurementsCount()
        let realmOperation = realm.getStoredMeasurementsCount()
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviStorageError> {
        let promise = Promise<SensorSettings?, RuuviStorageError>()
        if ruuviTag.macId != nil {
            sqlite.readSensorSettings(ruuviTag).on(success: { settings in
                promise.succeed(value: settings)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.readSensorSettings(ruuviTag).on(success: { settings in
                promise.succeed(value: settings)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        return promise.future
    }
}
