#if SWIFT_PACKAGE
    import RuuviRepository
#endif
import Foundation
import RuuviOntology
import RuuviPool
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
    ) async throws(RuuviRepositoryError) -> AnyRuuviTagSensorRecord {
        var outcome: Result<AnyRuuviTagSensorRecord, RuuviRepositoryError>
        do {
            let _ = try await pool.create(record)
            outcome = .success(record.any)
        } catch let error {
            outcome = .failure(.ruuviPool(error))
        }
        return try outcome.get()
    }

    func create(
        records: [RuuviTagSensorRecord],
        for _: RuuviTagSensor
    ) async throws(RuuviRepositoryError) -> [AnyRuuviTagSensorRecord] {
        var outcome: Result<[AnyRuuviTagSensorRecord], RuuviRepositoryError>
        let mappedRecords = records.map(\.any)
        do {
            let _ = try await pool.create(mappedRecords)
            outcome = .success(mappedRecords)
        } catch let error {
            outcome = .failure(.ruuviPool(error))
        }
        return try outcome.get()
    }
}
