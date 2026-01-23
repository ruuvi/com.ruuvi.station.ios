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
                await MainActor.run {
                    presenter.interactorDidUpdate(tokens: tokens)
                }
            } catch {
                await MainActor.run {
                    presenter.interactorDidError(.networking(error))
                }
            }
        }
    }
}
