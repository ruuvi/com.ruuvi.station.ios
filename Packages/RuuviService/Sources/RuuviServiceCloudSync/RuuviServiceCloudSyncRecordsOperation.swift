import Foundation
import RuuviCloud
import RuuviLocal
import RuuviOntology
import RuuviRepository

final class RuuviServiceCloudSyncRecordsOperation: AsyncOperation {
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
                let loadedRecords = try await self.loadCloudRecords(macId: macId, since: since, until: until)
                guard !loadedRecords.isEmpty else {
                    self.state = .finished
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
                do {
                    _ = try await self.persistRecords(recordsWithLuid, for: self.sensor)
                    self.records = recordsWithLuid
                } catch {
//                    self.error = .ruuviRepository(error)
                }
                self.state = .finished
            } catch {
//                self.error = .ruuviCloud(error)
                self.state = .finished
            }
        }
    }
}

// MARK: - Async direct calls
private extension RuuviServiceCloudSyncRecordsOperation {
    func loadCloudRecords(macId: MACIdentifier, since: Date, until: Date?) async throws -> [AnyRuuviTagSensorRecord] {
        try await ruuviCloud.loadRecords(macId: macId, since: since, until: until)
    }

    func persistRecords(_ records: [AnyRuuviTagSensorRecord], for sensor: RuuviTagSensor) async throws -> Bool {
        _ = try await ruuviRepository.create(records: records.compactMap { $0 }, for: sensor)
        return true
    }
}
