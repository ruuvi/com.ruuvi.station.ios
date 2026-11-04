import Foundation
import RuuviOntology
import RuuviService

class DevicesInteractor {
    weak var presenter: DevicesInteractorOutput!
    var ruuviServiceCloudNotification: RuuviServiceCloudNotification!
}

extension DevicesInteractor: DevicesInteractorInput {
    func fetchDevices() {
        Task { @MainActor [weak self, ruuviServiceCloudNotification = ruuviServiceCloudNotification!] in
            do {
                let value = try await ruuviServiceCloudNotification.listTokens()
                ({
                    [weak self] tokens in
                    self?.presenter.interactorDidUpdate(tokens: tokens)
                })(value)
            } catch {
                ({ [weak self] error in
                    self?.presenter.interactorDidError(.networking(error))
                })(error)
            }
        }
    }
}
