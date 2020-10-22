import Foundation
import Future

class TagsManagerPresenter {
    weak var view: TagsManagerViewInput!
    var output: TagsManagerModuleOutput!
    var router: TagsManagerRouterInput!

    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var keychainService: KeychainService!
    var userApiService: RuuviNetworkUserApi!

    private var viewModel: TagsManagerViewModel! {
        didSet {
            view.viewModel = viewModel
        }
    }
}
// MARK: - TagsManagerViewOutput
extension TagsManagerPresenter: TagsManagerViewOutput {
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
// MARK: - TagsManagerModuleInput
extension TagsManagerPresenter: TagsManagerModuleInput {
    func configure(output: TagsManagerModuleOutput) {
        self.output = output
        fetchUserData()
    }

    func dismiss() {
        router.dismiss(completion: nil)
    }

    func viewDidTapAction(_ action: TagManagerActionType) {
        switch action {
        case .addMissingTag:
            break
        }
    }
}
// MARK: - Private
extension TagsManagerPresenter {
    private func syncViewModel() {
        viewModel = TagsManagerViewModel()
        viewModel.title.value = keychainService.userApiEmail
        viewModel.actions.value = TagManagerActionType.allCases
    }

    private func bindViewModel() {
    }

    private func createAlert() {
        let title = "TagsManagerPresenter.SignOutConfirmAlert.Title".localized()
        let message = "TagsManagerPresenter.SignOutConfirmAlert.Message".localized()
        let confirmActionTitle = "TagsManagerPresenter.SignOutConfirmAlert.ConfirmAction".localized()
        let cancelActionTitle = "TagsManagerPresenter.SignOutConfirmAlert.CancelAction".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            self?.keychainService.userApiLogOut()
            self?.dismiss()
        }
        let cancleAction = UIAlertAction(title: cancelActionTitle,
                                         style: .cancel,
                                         handler: nil)
        let actions = [ confirmAction, cancleAction ]
        let alertViewModel = TagsManagerAlertViewModel(title: title,
                                                         message: message,
                                                         style: .alert,
                                                         actions: actions)
        router.showAlert(alertViewModel)
    }

    private func fetchUserData() {
        activityPresenter.increment()
        userApiService.user()
            .on(success: { [weak self] (response) in
                self?.viewModel.items.value = response.sensors.map({ TagManagerCellViewModel(sensor: $0) })
            }, failure: { [weak self] (error) in
                self?.errorPresenter.present(error: error)
            }, completion: { [weak self] in
                self?.activityPresenter.decrement()
            })
    }
}
