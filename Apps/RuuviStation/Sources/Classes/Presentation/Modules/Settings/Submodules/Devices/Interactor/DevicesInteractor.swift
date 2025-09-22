import Foundation
import RuuviOntology
import RuuviService

class DevicesInteractor {
    weak var presenter: DevicesInteractorOutput!
    var ruuviServiceCloudNotification: RuuviServiceCloudNotification!
}

extension DevicesInteractor: DevicesInteractorInput {
    func fetchDevices() {
        Task { [weak self] in
            guard let self else { return }
            do {
                let tokens = try await ruuviServiceCloudNotification.listTokens()
                presenter.interactorDidUpdate(tokens: tokens)
            } catch {
                if let error = error as? RuuviServiceError {
                    presenter.interactorDidError(.networking(error))
                }
            }
        }
    }
}
