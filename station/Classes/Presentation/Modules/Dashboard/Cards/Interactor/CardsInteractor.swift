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
    func checkAndUpdateFirmwareVersion(for ruuviTag: RuuviTagSensor) {
        guard let luid = ruuviTag.luid?.value,
        ruuviTag.firmwareVersion == nil else {
            return
        }

        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid,
            options: [.connectionTimeout(15)]
        ) { [weak self] _, result in
            switch result {
            case .success(let version):
                // TODO: - @priyonto - Handle this prefix properly.
                let currentVersion = version.replace("Ruuvi FW ", with: "")
                let tagWithVersion = ruuviTag.with(firmwareVersion: currentVersion)
                self?.ruuviPool.update(tagWithVersion)
            default:
                break
            }
        }
    }
}
