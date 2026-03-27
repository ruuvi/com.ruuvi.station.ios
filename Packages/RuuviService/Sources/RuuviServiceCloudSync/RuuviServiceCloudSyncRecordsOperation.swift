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
        Task { [weak self] in
            guard let self else { return }
            do {
                let loadedRecords = try await ruuviCloud.loadRecords(
                    macId: macId,
                    since: since,
                    until: until
                )
                guard !loadedRecords.isEmpty else {
                    state = .finished
                    return
                }
                let recordsWithLuid: [AnyRuuviTagSensorRecord] = loadedRecords.map { record in
                    if record.luid == nil,
                       let macId = record.macId,
                       let luid = self.ruuviLocalIDs.luid(for: macId) {
                        record.with(luid: luid).any
                    } else {
                        record
                    }
                }
                _ = try await ruuviRepository.create(
                    records: recordsWithLuid,
                    for: sensor
                )
                self.records = recordsWithLuid
                self.state = .finished
                
            } catch let error as RuuviCloudError {
                self.error = .ruuviCloud(error)
                self.state = .finished
            } catch let error as RuuviRepositoryError {
                self.error = .ruuviRepository(error)
                self.state = .finished
            } catch {
                self.error = .networking(error)
                self.state = .finished
            }
        }
    }
}
