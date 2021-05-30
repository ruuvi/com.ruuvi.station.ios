import Foundation
import RuuviPool
import RuuviCloud
import RuuviLocal
import RuuviOntology

final class RuuviServiceCloudSyncRecordsOperation: AsyncOperation {
    var macId: MACIdentifier
    var error: RuuviServiceError?
    var records: [AnyRuuviTagSensorRecord] = []
    private var since: Date
    private var until: Date?
    private var ruuviCloud: RuuviCloud
    private var ruuviPool: RuuviPool
    private var syncState: RuuviLocalSyncState

    init(macId: MACIdentifier,
         since: Date,
         until: Date? = nil,
         ruuviCloud: RuuviCloud,
         ruuviPool: RuuviPool,
         syncState: RuuviLocalSyncState) {
        self.macId = macId
        self.since = since
        self.until = until
        self.ruuviCloud = ruuviCloud
        self.ruuviPool = ruuviPool
        self.syncState = syncState
    }

    override func main() {
        let op = ruuviCloud.loadRecords(macId: macId, since: since, until: until)
        syncState.setSyncStatus(.syncing, for: macId)
        op.on(success: { [weak self] records in
            guard let sSelf = self else { return }
            guard !records.isEmpty else {
                sSelf.state = .finished
                sSelf.syncState.setSyncStatus(.complete, for: sSelf.macId)
                return
            }
            let persist = sSelf.ruuviPool.create(records)
            persist.on(success: { [weak sSelf] _ in
                guard let ssSelf = sSelf else { return }
                ssSelf.records = records
                ssSelf.syncState.setSyncStatus(.complete, for: ssSelf.macId)
                ssSelf.state = .finished
            }, failure: { [weak sSelf] error in
                guard let ssSelf = sSelf else { return }
                ssSelf.error = .ruuviPool(error)
                ssSelf.syncState.setSyncStatus(.onError, for: ssSelf.macId)
                ssSelf.state = .finished
            })
        }, failure: { [weak self] error in
            guard let sSelf = self else { return }
            sSelf.error = .ruuviCloud(error)
            sSelf.syncState.setSyncStatus(.onError, for: sSelf.macId)
            sSelf.state = .finished
        })
    }
}
