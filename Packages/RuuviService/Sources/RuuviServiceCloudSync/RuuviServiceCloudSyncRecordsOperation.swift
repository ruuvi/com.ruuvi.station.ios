import Foundation
import RuuviRepository
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviService

final class RuuviServiceCloudSyncRecordsOperation: AsyncOperation {
    var sensor: RuuviTagSensor
    var error: RuuviServiceError?
    var records: [AnyRuuviTagSensorRecord] = []
    private var since: Date
    private var until: Date?
    private var ruuviCloud: RuuviCloud
    private var ruuviRepository: RuuviRepository
    private var syncState: RuuviLocalSyncState
    private var ruuviLocalIDs: RuuviLocalIDs

    init(sensor: RuuviTagSensor,
         since: Date,
         until: Date? = nil,
         ruuviCloud: RuuviCloud,
         ruuviRepository: RuuviRepository,
         syncState: RuuviLocalSyncState,
         ruuviLocalIDs: RuuviLocalIDs
    ) {
        self.sensor = sensor
        self.since = since
        self.until = until
        self.ruuviCloud = ruuviCloud
        self.ruuviRepository = ruuviRepository
        self.syncState = syncState
        self.ruuviLocalIDs = ruuviLocalIDs
    }

    override func main() {
        guard let macId = sensor.macId else {
            error = .macIdIsNil
            state = .finished
            return
        }
        let op = ruuviCloud.loadRecords(macId: macId, since: since, until: until)
        syncState.setSyncStatus(.syncing, for: macId)
        op.on(success: { [weak self] loadedRecords in
            guard let sSelf = self else { return }
            guard !loadedRecords.isEmpty else {
                sSelf.state = .finished
                sSelf.syncState.setSyncStatus(.complete, for: macId)
                return
            }
            let recordsWithLuid: [AnyRuuviTagSensorRecord] = loadedRecords.map({ record in
                if record.luid == nil,
                   let macId = record.macId,
                   let luid = sSelf.ruuviLocalIDs.luid(for: macId) {
                    return record.with(luid: luid).any
                } else {
                    return record
                }
            })
            let persist = sSelf.ruuviRepository.create(
                records: recordsWithLuid,
                for: sSelf.sensor
            )
            persist.on(success: { [weak sSelf] _ in
                guard let ssSelf = sSelf else { return }
                ssSelf.records = recordsWithLuid
                ssSelf.syncState.setSyncStatus(.complete, for: macId)
                ssSelf.state = .finished
            }, failure: { [weak sSelf] error in
                guard let ssSelf = sSelf else { return }
                ssSelf.error = .ruuviRepository(error)
                ssSelf.syncState.setSyncStatus(.onError, for: macId)
                ssSelf.state = .finished
            })
        }, failure: { [weak self] error in
            guard let sSelf = self else { return }
            sSelf.error = .ruuviCloud(error)
            sSelf.syncState.setSyncStatus(.onError, for: macId)
            sSelf.state = .finished
        })
    }
}
