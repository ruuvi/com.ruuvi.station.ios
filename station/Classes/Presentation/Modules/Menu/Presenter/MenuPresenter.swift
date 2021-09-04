import UIKit
import RuuviService
import RuuviLocal
import RuuviUser

class MenuPresenter: MenuModuleInput {
    weak var view: MenuViewInput!
    var router: MenuRouterInput!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var cloudSyncService: RuuviServiceCloudSync!
    var ruuviUser: RuuviUser!
    var localSyncState: RuuviLocalSyncState!
    var featureToggleService: FeatureToggleService!
    var authService: RuuviServiceAuth!

    var viewModel: MenuViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }

    private var timer: Timer?
    private var lastSyncDate: CFAbsoluteTime!
    private var syncNotificationToken: NSObjectProtocol?

    private weak var output: MenuModuleOutput?

    func configure(output: MenuModuleOutput) {
        self.output = output
        startObservingAppState()
    }

    func dismiss() {
        router.dismiss()
    }

    deinit {
        syncNotificationToken?.invalidate()
        timer?.invalidate()
    }
}

extension MenuPresenter: MenuViewOutput {

    func viewDidLoad() {
        view.isNetworkHidden = !featureToggleService.isEnabled(.network)
        syncViewModel()
    }

    var userIsAuthorized: Bool {
        return ruuviUser.isAuthorized
    }

    var userEmail: String? {
        return ruuviUser.email
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
        cloudSyncService.syncAll()
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
        syncNotificationToken = NotificationCenter
            .default
            .addObserver(forName: .NetworkSyncDidChangeCommonStatus,
                         object: nil,
                         queue: .main,
                         using: { [weak self] notification in
            guard let status = notification.userInfo?[NetworkSyncStatusKey.status] as? NetworkSyncStatus else {
                return
            }
            if status == .syncing {
                self?.invalidateTimer()
                self?.viewModel?.isSyncing.value = true
                self?.lastSyncDate = CFAbsoluteTimeGetCurrent()
            } else {
                self?.viewModel?.isSyncing.value = false
                self?.setSyncStatus()
                self?.createLastUpdateTimer()
            }
        })
    }

    @objc private func syncViewModel() {
        let viewModel = MenuViewModel()
        if ruuviUser.isAuthorized {
            viewModel.username.value = ruuviUser.email
        }
        viewModel.isSyncing.value = localSyncState.syncStatus == .syncing
        self.viewModel = viewModel
        guard localSyncState.syncStatus != .syncing else {
            return
        }
        setSyncStatus()
        createLastUpdateTimer()
    }

    @objc private func invalidateTimer() {
        timer?.invalidate()
    }

    private func setSyncStatus() {
        let prefix = "Synchronized".localized()
        if let date = localSyncState.latestSyncDate?.ruuviAgo(prefix: prefix) {
            viewModel?.status.value = date
        } else {
            viewModel?.status.value = localSyncState.latestSyncDate?.ruuviAgo(prefix: prefix) ?? "N/A".localized()
        }
    }

    private func createLastUpdateTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] (_) in
            self?.setSyncStatus()
        })
    }

    private func createSignOutAlert() {
        let title = "Menu.SignOut.text".localized()
        let message = "TagsManagerPresenter.SignOutConfirmAlert.Message".localized()
        let confirmActionTitle = "OK".localized()
        let cancelActionTitle = "Cancel".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            guard let sSelf = self else { return }
            sSelf.authService.logout()
                .on(success: { [weak sSelf] _ in
                    sSelf?.dismiss()
                }, failure: { [weak sSelf] error in
                    sSelf?.errorPresenter.present(error: error)
                })
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
