import UIKit

class NetworkSettingsPresenter: NSObject {
    weak var view: NetworkSettingsViewInput!
    var router: NetworkSettingsRouterInput!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var settings: Settings!

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
    /// in minutes
    private let minNetworkRefreshInterval: Double = 1
}
// MARK: - NetworkSettingsModuleInput
extension NetworkSettingsPresenter: NetworkSettingsModuleInput {
    func configure() {
        syncViewModel()
    }
}
// MARK: - NetworkSettingsViewOutput
extension NetworkSettingsPresenter: NetworkSettingsViewOutput {
    func viewDidLoad() {
    }

    func viewDidTriggerNetworkFeatureSwitch(_ state: Bool) {
//        TODO: @rinatenikeev ENABLE FEATURE TOGGLE
//        settings.networkFeatureEnabled = state
        viewModel.networkFeatureEnabled.value = state
    }
}
// MARK: - Private
extension NetworkSettingsPresenter {
    private func syncViewModel() {
        viewModel = NetworkSettingsViewModel()
//        TODO: @rinatenikeev ENABLE FEATURE TOGGLE
//        viewModel.networkFeatureEnabled.value = settings.networkFeatureEnabled
        viewModel.minNetworkRefreshInterval.value = minNetworkRefreshInterval
        viewModel.networkRefreshInterval.value = settings.networkPullIntervalSeconds / 60
        bindNetworkRefreshIntervalChanges()
    }

    private func bindNetworkRefreshIntervalChanges() {
        bind(viewModel.networkRefreshInterval) { (sSelf, newValue) in
            if let value = newValue {
                sSelf.settings.networkPullIntervalSeconds = value * 60
            }
        }
    }
}
