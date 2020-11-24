import UIKit

class MenuPresenter: MenuModuleInput {
    weak var view: MenuViewInput!
    var router: MenuRouterInput!
    var alertPresenter: AlertPresenter!
    var networkService: NetworkService!
    var keychainService: KeychainService!
    var networkPersistence: NetworkPersistence!

    var viewModel: MenuViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }

    private var timer: Timer?

    private weak var output: MenuModuleOutput?

    func configure(output: MenuModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss()
    }

    deinit {
        timer?.invalidate()
    }
}

extension MenuPresenter: MenuViewOutput {

    func viewDidLoad() {
        syncViewModel()
        createLastUpdateTimer()
    }

    var userIsAuthorized: Bool {
        return keychainService.userApiIsAuthorized
    }

    var userEmail: String? {
        return keychainService.userApiEmail
    }

    func viewDidTapOnDimmingView() {
        router.dismiss()
    }

    func viewDidSelectAddRuuviTag() {
        output?.menu(module: self, didSelectAddRuuviTag: nil)
    }

    func viewDidSelectAbout() {
        output?.menu(module: self, didSelectAbout: nil)
    }

    func viewDidSelectGetMoreSensors() {
        output?.menu(module: self, didSelectGetMoreSensors: nil)
    }

    func viewDidSelectSettings() {
        output?.menu(module: self, didSelectSettings: nil)
    }

    func viewDidSelectFeedback() {
        output?.menu(module: self, didSelectFeedback: nil)
    }

    func viewDidSelectAccountCell() {
        if userIsAuthorized {
            createSignOutAlert()
        } else {
            output?.menu(module: self, didSelectSignIn: nil)
        }
    }

    func viewDidTapSyncButton() {
        timer?.invalidate()
        viewModel?.isSyncing.value = true
        networkService.updateTagsInfo(for: .userApi)
            .on(completion: { [weak self] in
                self?.viewModel?.isSyncing.value = false
                self?.createLastUpdateTimer()
            })
    }
}

extension MenuPresenter {
    private func syncViewModel() {
        let viewModel = MenuViewModel()
        viewModel.username.value = keychainService.userApiEmail
        self.viewModel = viewModel
    }

    private func createLastUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            let prefix = "Synchronized".localized()
            if let date = self?.networkPersistence.lastSyncDate?.ruuviAgo(prefix: prefix) {
                self?.viewModel?.status.value = date
            } else {
                self?.viewModel?.status.value = self?.networkPersistence.lastSyncDate?.ruuviAgo(prefix: prefix) ?? "N/A".localized()
            }
        })
    }

    private func createSignOutAlert() {
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
        let alertViewModel = AlertViewModel(title: title,
                                                         message: message,
                                                         style: .alert,
                                                         actions: actions)
        alertPresenter.showAlert(alertViewModel)
    }
}
