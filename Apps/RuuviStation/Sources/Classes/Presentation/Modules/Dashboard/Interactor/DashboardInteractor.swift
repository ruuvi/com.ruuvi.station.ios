import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviService
import RuuviStorage
import RuuviUser

class DashboardInteractor {
    var connectionPersistence: RuuviLocalConnections!
    var background: BTBackground!
    var ruuviPool: RuuviPool!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var settings: RuuviLocalSettings!
    var ruuviUser: RuuviUser!
    var ruuviStorage: RuuviStorage!
    var ownerCheckDelay: TimeInterval = 2
    var readFirmwareVersion: ((String, @escaping (Result<String, Error>) -> Void) -> Void)?
    private var checkingSensors = Set<String>()
}

extension DashboardInteractor: DashboardInteractorInput {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        Task { @MainActor [self] in
            guard checkingSensors.insert(ruuviTag.id).inserted else { return }
            defer { checkingSensors.remove(ruuviTag.id) }
            var current = await latestSensor(for: ruuviTag)
            if current.firmwareVersion?.isEmpty != false, let luid = current.luid {
                if let version = await firmwareVersion(for: luid.value) {
                    current = await latestSensor(for: current)
                    current = current.with(firmwareVersion: version)
                    _ = try? await ruuviPool.update(current)
                }
            } else if ownerCheckDelay > 0 {
                try? await Task.sleep(for: .seconds(ownerCheckDelay))
            }
            await checkOwner(for: current)
        }
    }

    @MainActor private func latestSensor(for sensor: RuuviTagSensor) async -> RuuviTagSensor {
        guard let ruuviStorage else { return sensor }
        return (try? await ruuviStorage.readOne(sensor.macId?.value ?? sensor.id)) ?? sensor.any
    }

    @MainActor private func firmwareVersion(for uuid: String) async -> String? {
        await withCheckedContinuation { continuation in
            let completed: (Result<String, Error>) -> Void = { result in
                continuation.resume(returning: try? result.get())
            }
            if let readFirmwareVersion {
                readFirmwareVersion(uuid, completed)
            } else {
                background.services.gatt.firmwareRevision(
                    for: self, uuid: uuid, options: [.connectionTimeout(15), .serviceTimeout(15)]
                ) { _, result in completed(result.mapError { $0 as Error }) }
            }
        }
    }

    @MainActor private func checkOwner(for sensor: RuuviTagSensor) async {
        let current = await latestSensor(for: sensor)
        guard let macId = current.macId, current.owner == nil else { return }
        if let checked = settings.ownerCheckDate(for: macId),
            let days = checked.numberOfDaysFromNow(), days < 15
        {
            return
        }
        do {
            let (owner, _) = try await ruuviOwnershipService.checkOwner(macId: macId)
            guard let owner, !owner.isEmpty else {
                settings.setOwnerCheckDate(for: macId, value: Date())
                NotificationCenter.default.post(
                    name: .RuuviTagOwnershipCheckDidEnd, object: nil,
                    userInfo: [RuuviTagOwnershipCheckResultKey.hasOwner: false])
                return
            }
            let latest = await latestSensor(for: current)
            let normalizedOwner = owner.lowercased()
            _ = try? await ruuviPool.update(
                latest.with(owner: normalizedOwner).with(isOwner: normalizedOwner == ruuviUser.email?.lowercased()))
        } catch {
            // A failed owner lookup remains eligible for a later retry.
        }
    }
}
