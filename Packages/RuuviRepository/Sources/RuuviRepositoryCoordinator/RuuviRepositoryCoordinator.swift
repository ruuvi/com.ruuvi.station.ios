import Foundation
import Future
import RuuviOntology
import RuuviPool
import RuuviRepository
import RuuviStorage

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
        for _: RuuviTagSensor
    ) -> Future<AnyRuuviTagSensorRecord, RuuviRepositoryError> {
        let promise = Promise<AnyRuuviTagSensorRecord, RuuviRepositoryError>()
        pool.create(record)
            .on(success: { _ in
                promise.succeed(value: record.any)
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }

    func create(
        records: [RuuviTagSensorRecord],
        for _: RuuviTagSensor
    ) -> Future<[AnyRuuviTagSensorRecord], RuuviRepositoryError> {
        let promise = Promise<[AnyRuuviTagSensorRecord], RuuviRepositoryError>()
        let mappedRecords = records.map(\.any)
        pool.create(mappedRecords)
            .on(success: { _ in
                promise.succeed(value: mappedRecords)
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }
}
