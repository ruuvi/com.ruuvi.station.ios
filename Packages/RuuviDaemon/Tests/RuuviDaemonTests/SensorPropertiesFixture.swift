import Foundation
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviReactor
#if SWIFT_PACKAGE
    import RuuviDaemon
    @testable import RuuviDaemonRuuviTag
#else
    @testable import RuuviDaemon
#endif

final class SensorPropertiesFixture {
    var observations = [(RuuviReactorChange<AnyRuuviTagSensor>) -> Void]()
    var scans = [(SensorPropertiesAdvertisement) -> Void]()
    var cancelledObservations = 0
    var cancelledScans = 0
    var macs = [String: String]()
    var luids = [String: String]()
    var updates = [RuuviTagSensorStruct]()
    var reads = [String]()
    var errors = [RuuviDaemonError]()
    var reportOnMainThread = true
    var updateError: RuuviPoolError?
    var readError: RuuviPersistenceError?
    var updateResult = true
    var beforeUpdate: (() async -> Void)?
    var beforeRead: (() async -> Void)?
    var cancelledUpdates = 0
    var finishedUpdates = 0
    var stored: RuuviTagSensorStruct
    let luid = UUID().uuidString
    let mac = "AA:BB:CC:DD:EE:FF"

    init() {
        stored = .init(
            version: 5, firmwareVersion: nil, luid: luid.luid, macId: mac.mac, serviceUUID: nil,
            isConnectable: true, name: "Room", isClaimed: false, isOwner: true, owner: nil,
            ownersPlan: nil, isCloudSensor: false, canShare: false, sharedTo: [], maxHistoryDays: nil)
        macs[luid] = mac
        luids[mac] = luid
    }

    func makeWorker() -> RuuviTagPropertiesDaemonBTKit {
        .init(
            client: .init(
                observeSensors: { callback in
                    self.observations.append(callback)
                    return { self.cancelledObservations += 1 }
                },
                scan: { callback in
                    self.scans.append(callback)
                    return { self.cancelledScans += 1 }
                },
                macForLuid: { self.macs[$0] },
                luidForMac: { self.luids[$0] },
                readSensor: read,
                updateSensor: update,
                report: {
                    self.reportOnMainThread = self.reportOnMainThread && Thread.isMainThread
                    self.errors.append($0)
                }))
    }

    @MainActor private func read(_ mac: String) async throws(RuuviPersistenceError) -> RuuviTagSensor {
        reads.append(mac)
        await beforeRead?()
        if let readError { throw readError }
        return stored
    }

    @MainActor private func update(_ sensor: RuuviTagSensor) async throws(RuuviPoolError) -> Bool {
        updates.append(sensor.struct)
        defer { finishedUpdates += 1 }
        await beforeUpdate?()
        if Task.isCancelled { cancelledUpdates += 1; return false }
        if let updateError { throw updateError }
        return updateResult
    }

    func advertisement(
        luid: String? = nil, mac: String? = "AA:BB:CC:DD:EE:FF", version: Int = 6
    ) -> SensorPropertiesAdvertisement {
        .init(luid: luid ?? self.luid, mac: mac, version: version, serviceUUID: "service", isConnectable: true)
    }
}
