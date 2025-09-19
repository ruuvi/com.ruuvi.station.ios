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
    ) async throws -> AnyRuuviTagSensorRecord {
        do {
            try await pool.create(record)
            return record.any
        } catch let error as RuuviPoolError {
            throw RuuviRepositoryError.ruuviPool(error)
        } catch {
            throw error
        }
    }

    func create(
        records: [RuuviTagSensorRecord],
        for _: RuuviTagSensor
    ) async throws -> [AnyRuuviTagSensorRecord] {
        let mappedRecords = records.map(\.any)
        do {
            try await pool.create(mappedRecords)
            return mappedRecords
        } catch let error as RuuviPoolError {
            throw RuuviRepositoryError.ruuviPool(error)
        } catch {
            throw error
        }
    }
}
