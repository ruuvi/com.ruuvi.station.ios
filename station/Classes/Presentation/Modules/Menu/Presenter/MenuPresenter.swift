import UIKit

class MenuPresenter: MenuModuleInput {
    weak var view: MenuViewInput!
    var router: MenuRouterInput!
    var alertPresenter: AlertPresenter!
    var networkService: NetworkService!
    var keychainService: KeychainService!
    var networkPersistence: NetworkPersistence!
    var featureToggleService: FeatureToggleService!

    var viewModel: MenuViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }

    private var timer: Timer?
    private var lastSyncDate: CFAbsoluteTime!

    private weak var output: MenuModuleOutput?

    func configure(output: MenuModuleOutput) {
        self.output = output
        startObservingAppState()
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
        view.isNetworkHidden = !featureToggleService.isEnabled(.network)
        syncViewModel()
    }

    var userIsAuthorized: Bool {
        return keychainService.userIsAuthorized
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
        lastSyncDate = CFAbsoluteTimeGetCurrent()
        networkService.updateTagsInfo(for: .userApi)
            .on(completion: { [weak self] in
                if let lastSyncDate = self?.lastSyncDate {
                    let syncLength: CFAbsoluteTime = CFAbsoluteTimeGetCurrent() - lastSyncDate
                    let deadline = max(2.0 - syncLength, 0.0)
                    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(deadline * 1000))) {
                        self?.viewModel?.isSyncing.value = false
                    }
                } else {
                    self?.viewModel?.isSyncing.value = false
                }
                self?.createLastUpdateTimer()
            })
    }
}

extension MenuPresenter {
    private func startObservingAppState() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(syncViewModel),
                                               name: UIApplication.willEnterForegroundNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(invalidateTimer),
                                               name: UIApplication.didEnterBackgroundNotification,
                                               object: nil)
    }

    @objc private func syncViewModel() {
        let viewModel = MenuViewModel()
        viewModel.username.value = keychainService.userApiEmail
        self.viewModel = viewModel
        setSyncStatus()
        createLastUpdateTimer()
    }

    @objc private func invalidateTimer() {
        timer?.invalidate()
    }

    private func setSyncStatus() {
        let prefix = "Synchronized".localized()
        if let date = networkPersistence.lastSyncDate?.ruuviAgo(prefix: prefix) {
            viewModel?.status.value = date
        } else {
            viewModel?.status.value = networkPersistence.lastSyncDate?.ruuviAgo(prefix: prefix) ?? "N/A".localized()
        }
    }

    private func createLastUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            self?.setSyncStatus()
        })
    }

    private func createSignOutAlert() {
        let title = "TagsManager.SignOutButton".localized()
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
