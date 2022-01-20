import Foundation
import RuuviOntology
import Future
import RuuviPool
import RuuviStorage
import RuuviRepository

final class RuuviRepositoryCoordinator: RuuviRepository {
    private let pool: RuuviPool
    private let storage: RuuviStorage

    init(
        pool: RuuviPool,
        storage: RuuviStorage
    ) {
        self.pool = pool
        self.storage = storage
    }

    func create(
        record: RuuviTagSensorRecord,
        for sensor: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensorRecord, RuuviRepositoryError> {
        let promise = Promise<AnyRuuviTagSensorRecord, RuuviRepositoryError>()
        storage.readSensorSettings(sensor)
            .on(success: { settings in
                let offseted = record
                    //.with(sensorSettings: settings)
                self.pool.create(offseted)
                    .on(success: { _ in
                        promise.succeed(value: offseted.any)
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        return promise.future
    }

    func create(
        records: [RuuviTagSensorRecord],
        for sensor: RuuviTagSensor
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviRepositoryError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviRepositoryError>()
        storage.readSensorSettings(sensor)
            .on(success: { settings in
                let offseted = records.map({ $0.any
                    //.with(sensorSettings: settings).any
                })
                self.pool.create(offseted)
                    .on(success: { _ in
                        promise.succeed(value: offseted)
                    }, failure: { error in
                        promise.fail(error: .ruuviPool(error))
                    })
            }, failure: { error in
                promise.fail(error: .ruuviStorage(error))
            })
        return promise.future
    }
}
