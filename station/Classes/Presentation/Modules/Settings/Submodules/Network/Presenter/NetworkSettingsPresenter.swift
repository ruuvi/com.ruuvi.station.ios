import UIKit

class NetworkSettingsPresenter {
    weak var view: NetworkSettingsViewInput!
    var router: NetworkSettingsRouterInput!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var settings: Settings!
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
    private var viewModel: NetworkSettingsViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - KaltiotSettingsModuleInput
extension NetworkSettingsPresenter: NetworkSettingsModuleInput {
    func configure() {
        syncViewModel()
    }
}
// MARK: - KaltiotSettingsViewOutput
extension NetworkSettingsPresenter: NetworkSettingsViewOutput {
    func viewDidLoad() {
    }
    func viewDidEnterApiKey(_ apiKey: String?) {
        validateApiKey(apiKey)
    }
    func viewDidTriggerNetworkFeatureSwitch(_ state: Bool) {
        settings.networkFeatureEnabled = state
        viewModel.networkFeatureEnabled.value = state
    }
    func viewDidTriggerWhereOsSwitch(_ state: Bool) {
        settings.whereOSNetworkEnabled = state
        viewModel.whereOSNetworkEnabled.value = state
    }
}
// MARK: - Private
extension NetworkSettingsPresenter {
    private func syncViewModel() {
        viewModel = NetworkSettingsViewModel()
        viewModel.networkFeatureEnabled.value = settings.networkFeatureEnabled
        viewModel.whereOSNetworkEnabled.value = settings.whereOSNetworkEnabled
        viewModel.kaltiotApiKey.value = keychainService.kaltiotApiKey
    }
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
            self?.viewModel.kaltiotApiKey.value = nil
            self?.errorPresenter.present(error: error)
        })
    }
}
