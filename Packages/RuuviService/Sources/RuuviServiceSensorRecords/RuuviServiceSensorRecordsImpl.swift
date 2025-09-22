import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool

public final class RuuviServiceSensorRecordsImpl: RuuviServiceSensorRecords {
    private let pool: RuuviPool
    private let localSyncState: RuuviLocalSyncState

    public init(
        pool: RuuviPool,
        localSyncState: RuuviLocalSyncState
    ) {
        self.pool = pool
        self.localSyncState = localSyncState
    }

    @discardableResult
    public func clear(for sensor: RuuviTagSensor) async throws {
        do {
            try await pool.deleteAllRecords(sensor.id)
            localSyncState.setSyncDate(nil, for: sensor.macId)
            localSyncState.setSyncDate(nil)
            localSyncState.setGattSyncDate(nil, for: sensor.macId)
        } catch let error as RuuviPoolError {
            throw RuuviServiceError.ruuviPool(error)
        } catch {
            throw error
        }
    }
}
