import Foundation
import RuuviOntology
import RuuviService

class DevicesInteractor {
    weak var presenter: DevicesInteractorOutput!
    var ruuviServiceCloudNotification: RuuviServiceCloudNotification!
}

extension DevicesInteractor: DevicesInteractorInput {
    func fetchDevices() {
        ruuviServiceCloudNotification.listTokens().on(success: {
            [weak self] tokens in
            self?.presenter.interactorDidUpdate(tokens: tokens)
        }, failure: { [weak self] error in
            self?.presenter.interactorDidError(.networking(error))
        })
    }
}
