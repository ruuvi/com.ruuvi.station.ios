import Foundation
import RuuviOntology
import RuuviPool
import RuuviStorage

actor RuuviRepositoryCoordinator: RuuviRepository {
    private let pool: RuuviPool
    private let storage: RuuviStorage

    init(
        pool: RuuviPool,
        storage: RuuviStorage
    ) {
        self.pool = pool
        self.storage = storage
    }

    private func mapPoolError<T>(_ operation: () async throws -> T) async throws -> T {
        do {
            return try await operation()
        } catch let error as RuuviPoolError {
            throw RuuviRepositoryError.ruuviPool(error)
        } catch {
            throw RuuviRepositoryError.ruuviPool(.ruuviPersistence(.grdb(error)))
        }
    }

    func create(
        record: RuuviTagSensorRecord,
        for _: RuuviTagSensor
    ) async throws -> AnyRuuviTagSensorRecord {
        _ = try await mapPoolError {
            try await pool.create(record)
        }
        return record.any
    }

    func create(
        records: [RuuviTagSensorRecord],
        for _: RuuviTagSensor
    ) async throws -> [AnyRuuviTagSensorRecord] {
        let mappedRecords = records.map(\.any)
        _ = try await mapPoolError {
            try await pool.create(records)
        }
        return mappedRecords
    }
}
