import Foundation
import RuuviOntology
import Future

final class RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviStoragePersistence
    private let realm: RuuviStoragePersistence

    init(sqlite: RuuviStoragePersistence, realm: RuuviStoragePersistence) {
        self.sqlite = sqlite
        self.realm = realm
    }

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviStorageError> {
        // MARK: - respect realm
        return sqlite.readOne(ruuviTagId)
    }

    func readAll(_ ruuviTagId: String) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll(ruuviTagId)
        let realmOperation = realm.readAll(ruuviTagId)
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
        })
        return promise.future
    }

    func readAll() -> Future<[RuuviTagSensor], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensor], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll()
        let realmOperation = realm.readAll()
        Future.zip(sqliteOperation, realmOperation)
            .on(success: { sqliteEntities, realmEntities in
            let combinedValues = sqliteEntities + realmEntities
            promise.succeed(value: combinedValues)
        }, failure: { error in
            promise.fail(error: error)
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
            promise.fail(error: error)
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
            promise.fail(error: error)
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
            promise.fail(error: error)
        })
        return promise.future
    }

    func readLast(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviStorageError> {
        if ruuviTag.macId != nil {
            return sqlite.readLast(ruuviTag)
        } else {
            return realm.readLast(ruuviTag)
        }
    }

    func getStoredTagsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let sqliteOperation = sqlite.getStoredTagsCount()
        let realmOperation = realm.getStoredTagsCount()
        Future.zip(sqliteOperation, realmOperation).on(success: { sqliteEntities, realmEntities in
            promise.succeed(value: sqliteEntities + realmEntities)
        }, failure: { error in
            promise.fail(error: error)
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
            promise.fail(error: error)
        })
        return promise.future
    }

    func readSensorSettings(_ ruuviTag: RuuviTagSensor) -> Future<SensorSettings?, RuuviStorageError> {
        if ruuviTag.macId != nil {
            return sqlite.readSensorSettings(ruuviTag)
        } else {
            return realm.readSensorSettings(ruuviTag)
        }
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviStorageError> {
        if ruuviTag.macId != nil {
            return sqlite.updateOffsetCorrection(type: type, with: value, of: ruuviTag, lastOriginalRecord: record)
        } else {
            return realm.updateOffsetCorrection(type: type, with: value, of: ruuviTag, lastOriginalRecord: record)
        }
    }
}
