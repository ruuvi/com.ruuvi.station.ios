import Foundation
import Future
import RuuviOntology
import RuuviPersistence

final class RuuviStorageCoordinator: RuuviStorage {
    private let sqlite: RuuviPersistence

    init(sqlite: RuuviPersistence) {
        self.sqlite = sqlite
    }

    func readOne(_ ruuviTagId: String) -> Future<AnyRuuviTagSensor, RuuviStorageError> {
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
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readAll() -> Future<[AnyRuuviTagSensor], RuuviStorageError> {
        let promise = Promise<[AnyRuuviTagSensor], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll()
        sqliteOperation
            .on(success: { sqliteEntities in
                let combinedValues = sqliteEntities
                promise.succeed(value: combinedValues.map(\.any))
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        return promise.future
    }

    func readAll(_ id: String, after date: Date) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readAll(id, after: date)
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
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
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readDownsampled(
        _ id: String,
        after date: Date,
        with intervalMinutes: Int,
        pick points: Double
    ) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readDownsampled(
            id,
            after: date,
            with: intervalMinutes,
            pick: points
        )
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
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
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readLast(_ id: String, from: TimeInterval) -> Future<[RuuviTagSensorRecord], RuuviStorageError> {
        let promise = Promise<[RuuviTagSensorRecord], RuuviStorageError>()
        let sqliteOperation = sqlite.readLast(id, from: from)
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
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
            assertionFailure()
        }
        return promise.future
    }

    func readLatest(_ ruuviTag: RuuviTagSensor) -> Future<RuuviTagSensorRecord?, RuuviStorageError> {
        let promise = Promise<RuuviTagSensorRecord?, RuuviStorageError>()
        if ruuviTag.macId != nil {
            sqlite.readLatest(ruuviTag).on(success: { record in
                promise.succeed(value: record)
            }, failure: { error in
                promise.fail(error: .ruuviPersistence(error))
            })
        } else {
            assertionFailure()
        }
        return promise.future
    }

    func getStoredTagsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let sqliteOperation = sqlite.getStoredTagsCount()
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func getClaimedTagsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let allTags = readAll()
        allTags.on(success: { tags in
            let claimedTags = tags.filter { $0.isClaimed && $0.isOwner }
            promise.succeed(value: claimedTags.count)
        })
        return promise.future
    }

    func getOfflineTagsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let allTags = readAll()
        allTags.on(success: { tags in
            let claimedTags = tags.filter { !$0.isCloud }
            promise.succeed(value: claimedTags.count)
        })
        return promise.future
    }

    func getStoredMeasurementsCount() -> Future<Int, RuuviStorageError> {
        let promise = Promise<Int, RuuviStorageError>()
        let sqliteOperation = sqlite.getStoredMeasurementsCount()
        sqliteOperation.on(success: { sqliteEntities in
            promise.succeed(value: sqliteEntities)
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
            assertionFailure()
        }
        return promise.future
    }

    // MARK: - Queued cloud requests

    func readQueuedRequests()
    -> Future<[RuuviCloudQueuedRequest], RuuviStorageError> {
        let promise = Promise<[RuuviCloudQueuedRequest], RuuviStorageError>()
        sqlite.readQueuedRequests().on(success: { requests in
            promise.succeed(value: requests)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readQueuedRequests(
        for key: String
    ) -> Future<[RuuviCloudQueuedRequest], RuuviStorageError> {
        let promise = Promise<[RuuviCloudQueuedRequest], RuuviStorageError>()
        sqlite.readQueuedRequests(for: key).on(success: { requests in
            promise.succeed(value: requests)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }

    func readQueuedRequests(
        for type: RuuviCloudQueuedRequestType
    ) -> Future<[RuuviCloudQueuedRequest], RuuviStorageError> {
        let promise = Promise<[RuuviCloudQueuedRequest], RuuviStorageError>()
        sqlite.readQueuedRequests(for: type).on(success: { requests in
            promise.succeed(value: requests)
        }, failure: { error in
            promise.fail(error: .ruuviPersistence(error))
        })
        return promise.future
    }
}
