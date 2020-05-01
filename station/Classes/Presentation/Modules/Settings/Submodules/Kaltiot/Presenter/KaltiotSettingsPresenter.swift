import UIKit

class KaltiotSettingsPresenter {
    weak var view: KaltiotSettingsViewInput!
    var router: KaltiotSettingsRouterInput!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var ruuviNetworkKaltiot: RuuviNetworkKaltiot!
    private var isLoading: Bool = false {
        didSet {
            if isLoading {
                activityPresenter.increment()
            } else {
                activityPresenter.decrement()
            }
        }
    }
    private var viewModel: KaltiotSettingsViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - KaltiotSettingsModuleInput
extension KaltiotSettingsPresenter: KaltiotSettingsModuleInput {
    func configure() {
        viewModel = KaltiotSettingsViewModel()
        viewModel.apiKey.value = keychainService.kaltiotApiKey
    }
}
// MARK: - KaltiotSettingsViewOutput
extension KaltiotSettingsPresenter: KaltiotSettingsViewOutput {
    func viewDidEnterApiKey(_ apiKey: String?) {
        validateApiKey(apiKey)
    }
}
// MARK: - Private
extension KaltiotSettingsPresenter {
    private func validateApiKey(_ apiKey: String?) {
        guard let apiKey = apiKey else {
            return
        }
        isLoading = true
        let op = ruuviNetworkKaltiot.validateApiKey(apiKey: apiKey)
        op.on(success: { [weak self] in            self?.isLoading = false
            self?.keychainService.kaltiotApiKey = apiKey
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
            feedback.prepare()
            self?.router.dismiss()
        }, failure: { [weak self] (error) in
            self?.isLoading = false
            self?.keychainService.kaltiotApiKey = nil
            self?.viewModel.apiKey.value = nil
            self?.errorPresenter.present(error: error)
        })
    }
}
