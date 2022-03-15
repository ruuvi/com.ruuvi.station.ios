import Foundation
import RuuviOntology
import RuuviLocal
import Future
import BTKit

class TagSettingsInteractor {
    var connectionPersistence: RuuviLocalConnections!
    var background: BTBackground!
}

extension TagSettingsInteractor: TagSettingsInteractorInput {
    func checkFirmwareVersion(for luid: String) -> Future<String, RUError> {
        let promise = Promise<String, RUError>()
        background.services.gatt.firmwareRevision(
            for: self,
            uuid: luid,
            options: [.connectionTimeout(5)]
        ) { _, result in
            switch result {
            case .success(let version):
                promise.succeed(value: version)
            case .failure(let error):
                promise.fail(error: .btkit(error))
            }
        }
        return promise.future
    }
}
