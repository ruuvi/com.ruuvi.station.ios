import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviRepository

final class RuuviServiceCloudSyncRecordsOperation: AsyncOperation, @unchecked Sendable {
    var sensor: RuuviTagSensor
    var error: RuuviServiceError?
    var records: [AnyRuuviTagSensorRecord] = []
    private var since: Date
    private var until: Date?
    private var ruuviCloud: RuuviCloud
    private var ruuviRepository: RuuviRepository
    private var ruuviLocalIDs: RuuviLocalIDs

    init(
        sensor: RuuviTagSensor,
        since: Date,
        until: Date? = nil,
        ruuviCloud: RuuviCloud,
        ruuviRepository: RuuviRepository,
        syncState _: RuuviLocalSyncState,
        ruuviLocalIDs: RuuviLocalIDs
    ) {
        self.sensor = sensor
        self.since = since
        self.until = until
        self.ruuviCloud = ruuviCloud
        self.ruuviRepository = ruuviRepository
        self.ruuviLocalIDs = ruuviLocalIDs
    }

    override func main() {
        guard let macId = sensor.macId
        else {
            error = .macIdIsNil
            state = .finished
            return
        }
        let op = ruuviCloud.loadRecords(macId: macId, since: since, until: until)
        op.on(success: { [weak self] loadedRecords in
            guard let sSelf = self else { return }
            guard !loadedRecords.isEmpty
            else {
                sSelf.state = .finished
                return
            }
            let recordsWithLuid: [AnyRuuviTagSensorRecord] = loadedRecords.map { record in
                if record.luid == nil,
                   let macId = record.macId,
                   let luid = sSelf.ruuviLocalIDs.luid(for: macId) {
                    record.with(luid: luid).any
                } else {
                    record
                }
            }
            let persist = sSelf.ruuviRepository.create(
                records: recordsWithLuid,
                for: sSelf.sensor
            )
            persist.on(success: { [weak sSelf] _ in
                guard let ssSelf = sSelf else { return }
                ssSelf.records = recordsWithLuid
                ssSelf.state = .finished
            }, failure: { [weak sSelf] error in
                guard let ssSelf = sSelf else { return }
                ssSelf.error = .ruuviRepository(error)
                ssSelf.state = .finished
            })
        }, failure: { [weak self] error in
            guard let sSelf = self else { return }
            sSelf.error = .ruuviCloud(error)
            sSelf.state = .finished
        })
    }
}
