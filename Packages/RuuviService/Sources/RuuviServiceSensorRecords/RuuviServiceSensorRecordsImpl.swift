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

    public func clear(for sensor: RuuviTagSensor) async throws {
        _ = try await RuuviServiceError.perform {
            _ = try await self.pool.deleteAllRecords(sensor.id)
            self.localSyncState.setSyncDate(nil, for: sensor.macId)
            self.localSyncState.setSyncDate(nil)
            self.localSyncState.setGattSyncDate(nil, for: sensor.macId)
            self.localSyncState.setAutoGattSyncAttemptDate(nil, for: sensor.macId)
        }
    }
}
