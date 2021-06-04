import Foundation
import RuuviRepository
import RuuviCloud
import RuuviLocal
import RuuviOntology

final class RuuviServiceCloudSyncRecordsOperation: AsyncOperation {
    var sensor: RuuviTagSensor
    var error: RuuviServiceError?
    var records: [AnyRuuviTagSensorRecord] = []
    private var since: Date
    private var until: Date?
    private var ruuviCloud: RuuviCloud
    private var ruuviRepository: RuuviRepository
    private var syncState: RuuviLocalSyncState

    init(sensor: RuuviTagSensor,
         since: Date,
         until: Date? = nil,
         ruuviCloud: RuuviCloud,
         ruuviRepository: RuuviRepository,
         syncState: RuuviLocalSyncState) {
        self.sensor = sensor
        self.since = since
        self.until = until
        self.ruuviCloud = ruuviCloud
        self.ruuviRepository = ruuviRepository
        self.syncState = syncState
    }

    override func main() {
        guard let macId = sensor.macId else {
            error = .macIdIsNil
            state = .finished
            return
        }
        let op = ruuviCloud.loadRecords(macId: macId, since: since, until: until)
        syncState.setSyncStatus(.syncing, for: macId)
        op.on(success: { [weak self] records in
            guard let sSelf = self else { return }
            guard !records.isEmpty else {
                sSelf.state = .finished
                sSelf.syncState.setSyncStatus(.complete, for: macId)
                return
            }
            let persist = sSelf.ruuviRepository.create(records: records, for: sSelf.sensor)
            persist.on(success: { [weak sSelf] _ in
                guard let ssSelf = sSelf else { return }
                ssSelf.records = records
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
