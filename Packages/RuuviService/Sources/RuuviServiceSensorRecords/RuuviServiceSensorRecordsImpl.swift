import Foundation
import Future
import RuuviOntology
import RuuviPool
import RuuviLocal

final class RuuviServiceSensorRecordsImpl: RuuviServiceSensorRecords {
    private let pool: RuuviPool
    private let localSyncState: RuuviLocalSyncState

    init(
        pool: RuuviPool,
        localSyncState: RuuviLocalSyncState
    ) {
        self.pool = pool
        self.localSyncState = localSyncState
    }

    @discardableResult
    func clear(for sensor: RuuviTagSensor) -> Future<Void, RuuviServiceError> {
        let promise = Promise<Void, RuuviServiceError>()
        pool.deleteAllRecords(sensor.id)
            .on(success: { [weak self] _ in
                guard let sSelf = self else { return }
                sSelf.localSyncState.setSyncDate(nil, for: sensor.macId)
                promise.succeed(value: ())
            }, failure: { error in
                promise.fail(error: .ruuviPool(error))
            })
        return promise.future
    }
}
