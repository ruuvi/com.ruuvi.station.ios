import Foundation
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviService

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
    public func clear(for sensor: RuuviTagSensor) -> Future<Void, RuuviServiceError> {
        let promise = Promise<Void, RuuviServiceError>()
        pool.deleteAllRecords(sensor.id)
            .on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.localSyncState.setSyncDate(nil, for: sensor.macId)
                sSelf.localSyncState.setSyncDate(nil)
                sSelf.localSyncState.setGattSyncDate(nil, for: sensor.macId)
                promise.succeed(value: ())
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }
}
