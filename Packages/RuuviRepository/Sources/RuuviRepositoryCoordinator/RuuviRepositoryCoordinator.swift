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
        self.pool.create(record)
            .on(success: { _ in
                promise.succeed(value: record.any)
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }

    func create(
        records: [RuuviTagSensorRecord],
        for sensor: RuuviTagSensor
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviRepositoryError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviRepositoryError>()
        let mappedRecords = records.map({ $0.any })
        self.pool.create(mappedRecords)
            .on(success: { _ in
                promise.succeed(value: mappedRecords)
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }
}
