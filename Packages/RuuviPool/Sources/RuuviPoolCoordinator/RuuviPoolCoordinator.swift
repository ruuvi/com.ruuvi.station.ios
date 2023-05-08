import Foundation
import Future
import RuuviOntology
import RuuviPersistence
import RuuviLocal
import RuuviPool

// swiftlint:disable:next type_body_length
final class RuuviPoolCoordinator: RuuviPool {
    private var sqlite: RuuviPersistence
    private var realm: RuuviPersistence
    private var idPersistence: RuuviLocalIDs
    private var settings: RuuviLocalSettings
    private var connectionPersistence: RuuviLocalConnections

    init(
        sqlite: RuuviPersistence,
        realm: RuuviPersistence,
        idPersistence: RuuviLocalIDs,
        settings: RuuviLocalSettings,
        connectionPersistence: RuuviLocalConnections
    ) {
        self.sqlite = sqlite
        self.realm = realm
        self.idPersistence = idPersistence
        self.settings = settings
        self.connectionPersistence = connectionPersistence
    }

    func create(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        if let macId = ruuviTag.macId,
            let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
        }
        if ruuviTag.macId != nil,
            ruuviTag.macId?.value.isEmpty == false {
            sqlite.create(ruuviTag).on(success: { (result) in
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.create(ruuviTag).on(success: { (result) in
                promise.succeed(value: result)
            }, failure: { (error) in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        if let macId = ruuviTag.macId, let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
            idPersistence.set(luid: luid, for: macId)
        }
        return promise.future
    }

    func update(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        if ruuviTag.macId != nil {
            sqlite.update(ruuviTag).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.update(ruuviTag).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        if let macId = ruuviTag.macId, let luid = ruuviTag.luid {
            idPersistence.set(mac: macId, for: luid)
            idPersistence.set(luid: luid, for: macId)
        }
        return promise.future
    }

    func delete(_ ruuviTag: RuuviTagSensor) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        if ruuviTag.macId != nil {
            sqlite.deleteOffsetCorrection(ruuviTag: ruuviTag).on(success: { [weak self] success in
                self?.sqlite.delete(ruuviTag).on(success: { [weak self] success in
                    if let luid = ruuviTag.luid {
                        self?.connectionPersistence.setKeepConnection(false, for: luid)
                    }
                    promise.succeed(value: success)
                }, failure: { error in
                    promise.fail(error: .ruuviPersistence(error))
                })
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.delete(ruuviTag).on(success: { [weak self] success in
                if let luid = ruuviTag.luid {
                    self?.connectionPersistence.setKeepConnection(false, for: luid)
                }
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        return promise.future

    }

    func create(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        if record.macId != nil {
            sqlite.create(record).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else if let luid = record.luid,
                  let macId = idPersistence.mac(for: luid) {
            sqlite.create(record.with(macId: macId)).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.create(record).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        return promise.future
    }

    func createLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        if record.macId != nil {
            sqlite.createLast(record).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else if let luid = record.luid,
                  let macId = idPersistence.mac(for: luid) {
            sqlite.createLast(record.with(macId: macId)).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.createLast(record).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        return promise.future
    }

    func updateLast(_ record: RuuviTagSensorRecord) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        if record.macId != nil {
            sqlite.updateLast(record).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else if let luid = record.luid,
                  let macId = idPersistence.mac(for: luid) {
            sqlite.updateLast(record.with(macId: macId)).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            realm.updateLast(record).on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        }
        return promise.future
    }

    func deleteLast(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        let sqliteOperation = sqlite.deleteLatest(ruuviTagId)
        let realmOpearion = realm.deleteLatest(ruuviTagId)
        Future.zip(sqliteOperation, realmOpearion).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func create(_ records: [RuuviTagSensorRecord]) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        let sqliteRecords = records.filter({ $0.macId != nil })
        let realmRecords = records.filter({ $0.macId == nil })
        let sqliteOperation = sqlite.create(sqliteRecords)
        let realmOpearion = realm.create(realmRecords)
        Future.zip(sqliteOperation, realmOpearion).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        let sqliteOperation = sqlite.deleteAllRecords(ruuviTagId)
        let realmOpearion = realm.deleteAllRecords(ruuviTagId)
        let cleanUpOperation = sqlite.cleanupDBSpace()
        Future.zip(sqliteOperation, realmOpearion, cleanUpOperation).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func deleteAllRecords(_ ruuviTagId: String, before date: Date) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        let sqliteOperation = sqlite.deleteAllRecords(ruuviTagId, before: date)
        let realmOpearion = realm.deleteAllRecords(ruuviTagId, before: date)
        let cleanUpOperation = sqlite.cleanupDBSpace()
        Future.zip(sqliteOperation, realmOpearion, cleanUpOperation).on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    @discardableResult
    func cleanupDBSpace() -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        sqlite.cleanupDBSpace().on(success: { _ in
            promise.succeed(value: true)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func updateOffsetCorrection(
        type: OffsetCorrectionType,
        with value: Double?,
        of ruuviTag: RuuviTagSensor,
        lastOriginalRecord record: RuuviTagSensorRecord?
    ) -> Future<SensorSettings, RuuviPoolError> {
        let promise = Promise<SensorSettings, RuuviPoolError>()
        if ruuviTag.macId != nil {
            sqlite.updateOffsetCorrection(
                type: type,
                with: value,
                of: ruuviTag,
                lastOriginalRecord: record)
                .on(success: { settings in
                    promise.succeed(value: settings)
                }, failure: { error in
                    promise.fail(error: .ruuviPersistence(error))
                })
        } else {
            realm.updateOffsetCorrection(
                type: type,
                with: value,
                of: ruuviTag,
                lastOriginalRecord: record)
                .on(success: { settings in
                    promise.succeed(value: settings)
                }, failure: { error in
                    promise.fail(error: .ruuviPersistence(error))
                })
        }
        return promise.future
    }

    // MARK: - Queued cloud requests
    func createQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        sqlite.createQueuedRequest(request)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        return promise.future
    }

    func deleteQueuedRequest(
        _ request: RuuviCloudQueuedRequest
    ) -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        sqlite.deleteQueuedRequest(request)
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        return promise.future
    }

    func deleteQueuedRequests() -> Future<Bool, RuuviPoolError> {
        let promise = Promise<Bool, RuuviPoolError>()
        sqlite.deleteQueuedRequests()
            .on(success: { success in
                promise.succeed(value: success)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        return promise.future
    }
}
