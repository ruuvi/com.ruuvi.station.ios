#if SWIFT_PACKAGE
    import RuuviService
#endif
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
    @MainActor
    public func clear(for sensor: RuuviTagSensor) async throws(RuuviServiceError) -> Void {
        var outcome: Result<Void, RuuviServiceError>
        do {
            let _ = try await pool.deleteAllRecords(sensor.id)
            let sSelf = self
            sSelf.localSyncState.setSyncDate(nil, for: sensor.macId)
            sSelf.localSyncState.setSyncDate(nil)
            sSelf.localSyncState.setGattSyncDate(nil, for: sensor.macId)
            sSelf.localSyncState.setAutoGattSyncAttemptDate(nil, for: sensor.macId)
            outcome = .success(())
        } catch let error {
            outcome = .failure(.ruuviPool(error))
        }
        return try outcome.get()
    }
}
