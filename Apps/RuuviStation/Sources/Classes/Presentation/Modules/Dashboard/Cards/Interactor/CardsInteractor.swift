import BTKit
import Foundation
import Future
import RuuviLocal
import RuuviOntology
import RuuviPool

class CardsInteractor {
    var connectionPersistence: RuuviLocalConnections!
    var background: BTBackground!
    var ruuviPool: RuuviPool!
}

extension CardsInteractor: CardsInteractorInput {
    func checkAndUpdateFirmwareVersion(
        for ruuviTag: RuuviTagSensor,
        settings _: RuuviLocalSettings
    ) {
        guard let luid = ruuviTag.luid,
              ruuviTag.firmwareVersion == nil ||
              !ruuviTag.firmwareVersion.hasText()
        else {
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
            default:
                break
            }
        }
    }
}
