import BTKit
import Foundation
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviService
import RuuviStorage
import RuuviUser

@MainActor
class DashboardInteractor {
    var connectionPersistence: RuuviLocalConnections!
    var background: BTBackground!
    var ruuviPool: RuuviPool!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var settings: RuuviLocalSettings!
    var ruuviUser: RuuviUser!
    var ruuviStorage: RuuviStorage!
}

extension DashboardInteractor: DashboardInteractorInput {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let currentTag = await resolveLatestSensor(for: ruuviTag)
            handleFirmwareVersionCheck(for: currentTag)
        }
    }

    private func checkOwner(for ruuviTag: RuuviTagSensor) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let currentTag = await resolveLatestSensor(for: ruuviTag)
            guard let macId = currentTag.macId,
                  currentTag.owner == nil else {
                return
            }

            // Check in every 15 days if the tag doesn't have any owner.
            if let checkedDate = settings.ownerCheckDate(for: macId),
               let days = checkedDate.numberOfDaysFromNow(), days < 15 {
                return
            }

            do {
                let result = try await ruuviOwnershipService.checkOwner(macId: macId)
                let owner = result.0
                guard let owner, !owner.isEmpty else {
                    NotificationCenter.default.post(
                        name: .RuuviTagOwnershipCheckDidEnd,
                        object: nil,
                        userInfo: [RuuviTagOwnershipCheckResultKey.hasOwner: false]
                    )
                    settings.setOwnerCheckDate(for: macId, value: Date())
                    return
                }

                let latestTag = await resolveLatestSensor(for: currentTag)
                let normalizedOwner = owner.lowercased()
                _ = try? await ruuviPool.update(
                    latestTag
                        .with(owner: normalizedOwner)
                        .with(isOwner: normalizedOwner == ruuviUser.email)
                )
            } catch {
                // ignore failures
            }
        }
    }

    private func handleFirmwareVersionCheck(for ruuviTag: RuuviTagSensor) {
        if let firmwareVersion = ruuviTag.firmwareVersion, !firmwareVersion.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                self?.checkOwner(for: ruuviTag)
            }
            return
        }

        guard let luid = ruuviTag.luid else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                self?.checkOwner(for: ruuviTag)
            }
            return
        }

        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid.value,
            options: [
                .connectionTimeout(15),
                .serviceTimeout(15),
            ]
        ) { [weak self] _, result in
            switch result {
            case let .success(version):
                self?.applyFirmwareVersion(version, to: ruuviTag)
            default:
                self?.checkOwner(for: ruuviTag)
            }
        }
    }

    private func applyFirmwareVersion(_ version: String, to ruuviTag: RuuviTagSensor) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let latestTag = await resolveLatestSensor(for: ruuviTag)
            let updatedTag = latestTag.with(firmwareVersion: version)
            _ = try? await ruuviPool.update(updatedTag)
            checkOwner(for: updatedTag)
        }
    }

    private func resolveLatestSensor(
        for ruuviTag: RuuviTagSensor
    ) async -> RuuviTagSensor {
        guard let ruuviStorage else {
            return ruuviTag
        }

        let sensorId = ruuviTag.macId?.value ?? ruuviTag.id
        if let sensor = try? await ruuviStorage.readOne(sensorId) {
            return sensor
        }
        return ruuviTag
    }
}
