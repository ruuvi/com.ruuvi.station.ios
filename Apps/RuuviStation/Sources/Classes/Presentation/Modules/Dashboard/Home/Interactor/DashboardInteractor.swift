import BTKit
import Foundation
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool
import RuuviService
import RuuviUser

class DashboardInteractor {
    var connectionPersistence: RuuviLocalConnections!
    var background: BTBackground!
    var ruuviPool: RuuviPool!
    var ruuviOwnershipService: RuuviServiceOwnership!
    var settings: RuuviLocalSettings!
    var ruuviUser: RuuviUser!
}

extension DashboardInteractor: DashboardInteractorInput {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        guard let luid = ruuviTag.luid,
              ruuviTag.firmwareVersion == nil ||
              !ruuviTag.firmwareVersion.hasText()
        else {
            // Trigger the method after 2 seconds so that sensor settings page can
            // be set and start observing for owner check notification.
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) { [weak self] in
                self?.checkOwner(for: ruuviTag)
            }
            return
        }

        // TODO: Remove this check once fw revision is supported for E0/F0
        let fwVersion = RuuviFirmwareVersion.firmwareVersion(from: ruuviTag.version)
        if fwVersion == .e0 || fwVersion == .f0 {
            return
        }

        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid.value,
            options: [.connectionTimeout(15)]
        ) { [weak self] _, result in
            switch result {
            case let .success(version):
                let tagWithVersion = ruuviTag.with(firmwareVersion: version)
                self?.ruuviPool.update(tagWithVersion)
                self?.checkOwner(for: tagWithVersion)
            default:
                self?.checkOwner(for: ruuviTag)
            }
        }
    }

    private func checkOwner(for ruuviTag: RuuviTagSensor) {
        guard let macId = ruuviTag.macId,
              ruuviTag.owner == nil
        else {
            return
        }

        // Check in every 15 days if the tag doesn't have any owner.
        if let checkedDate = settings.ownerCheckDate(for: macId),
           let days = checkedDate.numberOfDaysFromNow(), days < 15 {
            return
        }

        ruuviOwnershipService.checkOwner(macId: macId)
            .on(success: { [weak self] owner in
                guard let sSelf = self
                else {
                    return
                }
                guard let owner, !owner.isEmpty
                else {
                    NotificationCenter.default.post(
                        name: .RuuviTagOwnershipCheckDidEnd,
                        object: nil,
                        userInfo: [RuuviTagOwnershipCheckResultKey.hasOwner: false]
                    )
                    sSelf.settings.setOwnerCheckDate(for: macId, value: Date())
                    return
                }
                sSelf.ruuviPool.update(ruuviTag
                    .with(owner: owner.lowercased())
                    .with(isOwner: owner.lowercased() == sSelf.ruuviUser.email))
            })
    }
}
