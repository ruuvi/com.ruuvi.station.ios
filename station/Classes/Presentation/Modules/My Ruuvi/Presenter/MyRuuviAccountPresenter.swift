import Foundation
import RuuviUser
import RuuviService
import RuuviPresenters
import RuuviCloud
import RuuviCore
import Future
import RuuviLocal

#if canImport(WidgetKit)
import WidgetKit
#endif

final class MyRuuviAccountPresenter: MyRuuviAccountModuleInput {
    weak var view: MyRuuviAccountViewInput!
    var router: MyRuuviAccountRouterInput!
    var ruuviCloud: RuuviCloud!
    var ruuviUser: RuuviUser!
    var authService: RuuviServiceAuth!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
    var activityPresenter: ActivityPresenter!
    var pnManager: RuuviCorePN!
    var cloudNotificationService: RuuviServiceCloudNotification!
    var settings: RuuviLocalSettings!
}

// MARK: - MyRuuviAccountViewOutput
extension MyRuuviAccountPresenter: MyRuuviAccountViewOutput {
    func viewDidLoad() {
        syncViewModel()
    }

    func viewDidTapDeleteButton() {
        guard let email = ruuviUser.email else { return }
        activityPresenter.increment()
        ruuviCloud.deleteAccount(email: email).on(success: {
            [weak self] _ in
            self?.view.viewDidShowAccountDeletionConfirmation()
        }, failure: { [weak self] error in
            self?.errorPresenter.present(error: error)
        }, completion: { [weak self] in
            self?.activityPresenter.decrement()
        })
    }

    func viewDidTapSignoutButton() {
        createSignOutAlert()
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }
}

// MARK: - Private
extension MyRuuviAccountPresenter {
    private func syncViewModel() {
        let viewModel = MyRuuviAccountViewModel()
        if ruuviUser.isAuthorized {
            viewModel.username.value = ruuviUser.email?.lowercased()
        }
        view.viewModel = viewModel
    }
}

extension MyRuuviAccountPresenter {

    private func createSignOutAlert() {
        let title = "Menu.SignOut.text".localized()
        let message = "TagsManagerPresenter.SignOutConfirmAlert.Message".localized()
        let confirmActionTitle = "OK".localized()
        let cancelActionTitle = "Cancel".localized()
        let confirmAction = UIAlertAction(title: confirmActionTitle,
                                          style: .default) { [weak self] (_) in
            guard let sSelf = self else { return }
            sSelf.cloudNotificationService.unregister(
                token: sSelf.pnManager.fcmToken,
                tokenId: nil
            ).on(success: { _ in
                sSelf.pnManager.fcmToken = nil
                sSelf.pnManager.fcmTokenLastRefreshed = nil
            })

            sSelf.authService.logout()
                .on(success: { _ in
                    sSelf.settings.cloudModeEnabled = false
                    sSelf.viewDidTriggerClose()
                    sSelf.syncViewModel()
                    sSelf.reloadWidgets()
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

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(ofKind: "ruuvi.simpleWidget")
    }
}
