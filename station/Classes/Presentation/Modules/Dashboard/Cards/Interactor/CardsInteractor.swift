import Foundation
import RuuviOntology
import RuuviLocal
import Future
import BTKit
import RuuviPool

class CardsInteractor {
    var connectionPersistence: RuuviLocalConnections!
    var background: BTBackground!
    var ruuviPool: RuuviPool!
}

extension CardsInteractor: CardsInteractorInput {
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor,
                                       settings: RuuviLocalSettings) {
        guard let luid = ruuviTag.luid,
              ruuviTag.firmwareVersion == nil ||
                !ruuviTag.firmwareVersion.hasText() &&
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
                let tagWithVersion = ruuviTag.with(firmwareVersion: version)
                self?.ruuviPool.update(tagWithVersion)
            default:
                break
            }
        }
    }
}

// TODO: - Deprecate this after version v1.3.2
extension CardsInteractor {
    func migrateFWVersionFromDefaults(for ruuviTags: [RuuviTagSensor],
                                      settings: RuuviLocalSettings) {
        for ruuviTag in ruuviTags {
            if let luid = ruuviTag.luid,
               let fwVersion = settings.firmwareVersion(for: luid) {
                ruuviPool.update(ruuviTag.with(firmwareVersion: fwVersion))
                settings.setFirmwareVersion(for: luid, value: nil)
            }
        }
    }
}
