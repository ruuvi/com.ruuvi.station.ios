import BTKit
import Foundation
import Future
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
}

extension DashboardInteractor: DashboardInteractorInput {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        resolveLatestSensor(for: ruuviTag) { [weak self] currentTag in
            self?.handleFirmwareVersionCheck(for: currentTag)
        }
    }

    private func checkOwner(for ruuviTag: RuuviTagSensor) {
        resolveLatestSensor(for: ruuviTag) { [weak self] currentTag in
            guard let self else { return }
            guard let macId = currentTag.macId,
                  currentTag.owner == nil else {
                return
            }

            // Check in every 15 days if the tag doesn't have any owner.
            if let checkedDate = self.settings.ownerCheckDate(for: macId),
               let days = checkedDate.numberOfDaysFromNow(), days < 15 {
                return
            }

            self.ruuviOwnershipService.checkOwner(macId: macId)
                .on(success: { [weak self] owner in
                    guard let self else { return }
                    guard let owner, !owner.isEmpty else {
                        NotificationCenter.default.post(
                            name: .RuuviTagOwnershipCheckDidEnd,
                            object: nil,
                            userInfo: [RuuviTagOwnershipCheckResultKey.hasOwner: false]
                        )
                        self.settings.setOwnerCheckDate(for: macId, value: Date())
                        return
                    }

                    self.resolveLatestSensor(for: currentTag) { [weak self] latestTag in
                        guard let self else { return }
                        let normalizedOwner = owner.lowercased()
                        self.ruuviPool.update(
                            latestTag
                                .with(owner: normalizedOwner)
                                .with(isOwner: normalizedOwner == self.ruuviUser.email)
                        )
                    }
                })
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
        resolveLatestSensor(for: ruuviTag) { [weak self] latestTag in
            guard let self else { return }
            let updatedTag = latestTag.with(firmwareVersion: version)
            self.ruuviPool.update(updatedTag)
            self.checkOwner(for: updatedTag)
        }
    }

    private func resolveLatestSensor(
        for ruuviTag: RuuviTagSensor,
        completion: @escaping (RuuviTagSensor) -> Void
    ) {
        guard let ruuviStorage else {
            completion(ruuviTag)
            return
        }

        let sensorId = ruuviTag.macId?.value ?? ruuviTag.id
        ruuviStorage.readOne(sensorId)
            .on(
                success: { completion($0) },
                failure: { _ in completion(ruuviTag) }
            )
    }
}
