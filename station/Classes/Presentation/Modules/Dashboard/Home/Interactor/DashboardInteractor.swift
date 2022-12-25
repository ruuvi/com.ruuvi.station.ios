import Foundation
import RuuviOntology
import RuuviLocal
import Future
import BTKit
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
              ruuviTag.firmwareVersion == nil &&
                settings.firmwareVersion(for: luid) == nil else {
            return
        }

        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid.value,
            options: [.connectionTimeout(15)]
        ) { [weak self] _, result in
            switch result {
            case .success(let version):
                // TODO: - @priyonto - Handle this prefix properly.
                let currentVersion = version.replace("Ruuvi FW ", with: "")
                let tagWithVersion = ruuviTag.with(firmwareVersion: currentVersion)
                self?.ruuviPool.update(tagWithVersion)
                self?.checkOwner(for: tagWithVersion)
            default:
                self?.checkOwner(for: ruuviTag)
            }
        }
    }

    private func checkOwner(for ruuviTag: RuuviTagSensor) {
        guard let macId = ruuviTag.macId,
              ruuviTag.owner == nil else {
            return
        }

        // Check in every 15 days if the tag doesn't have any owner.
        if let checkedDate = settings.ownerCheckDate(for: macId),
           let days = checkedDate.numberOfDaysFromNow(), days < 15 {
            return
        }

        ruuviOwnershipService.checkOwner(macId: macId)
            .on(success: { [weak self] owner in
                guard let self = self, !owner.isEmpty else {
                    self?.settings.setOwnerCheckDate(for: macId, value: Date())
                    return
                }
                self.ruuviPool.update(ruuviTag
                    .with(owner: owner)
                    .with(isOwner: owner == self.ruuviUser.email))
            })
    }
}

// TODO: - Deprecate this after version v1.3.2
extension DashboardInteractor {
    func migrateFWVersionFromDefaults(for ruuviTags: [RuuviTagSensor]) {
        for ruuviTag in ruuviTags {
            if let luid = ruuviTag.luid,
               let fwVersion = settings.firmwareVersion(for: luid) {
                ruuviPool.update(ruuviTag.with(firmwareVersion: fwVersion))
                settings.setFirmwareVersion(for: luid, value: nil)
            }
        }
    }
}
