import Foundation
import Future

class UserApiConfigPresenter {
    weak var view: UserApiConfigViewInput!
    var output: UserApiConfigModuleOutput!
    var router: UserApiConfigRouterInput!

    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var userApiService: RuuviNetworkUserApi!

    private var viewModel: UserApiConfigViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - UserApiConfigViewOutput
extension UserApiConfigPresenter: UserApiConfigViewOutput {
    func viewDidLoad() {
        syncViewModel()
        bindViewModel()
    }

    func viewDidCloseButtonTap() {
        router.dismiss()
    }

    func viewDidSignOutButtonTap() {
        createAlert()
    }
}
// MARK: - UserApiConfigModuleInput
extension UserApiConfigPresenter: UserApiConfigModuleInput {
    func configure(output: UserApiConfigModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }
}
// MARK: - Private
extension UserApiConfigPresenter {
    private func syncViewModel() {
        viewModel = UserApiConfigViewModel()
        viewModel.title.value = keychainService.userApiEmail
    }

    private func bindViewModel() {
    }

    private func createAlert() {
        let title = "UserApiConfigPresenter.SignOutConfirmAlert.Title".localized()
        let message = "UserApiConfigPresenter.SignOutConfirmAlert.Message".localized()
        let confirmActionTitle = "UserApiConfigPresenter.SignOutConfirmAlert.ConfirmAction".localized()
        let cancelActionTitle = "UserApiConfigPresenter.SignOutConfirmAlert.CancelAction".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            self?.keychainService.userApiLogOut()
            self?.dismiss()
        }
        let cancleAction = UIAlertAction(title: cancelActionTitle,
                                         style: .cancel,
                                         handler: nil)
        let actions = [ confirmAction, cancleAction ]
        let alertViewModel = UserApiConfigAlertViewModel(title: title,
                                                         message: message,
                                                         style: .alert,
                                                         actions: actions)
        router.showAlert(alertViewModel)
    }
}
