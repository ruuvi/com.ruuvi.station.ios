import Foundation
// Future removed: using async/await APIs
import RuuviCloud
import RuuviCore
import RuuviLocal
import RuuviLocalization
import RuuviPresenters
import RuuviService
import RuuviUser
import UIKit

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
    var mailComposerPresenter: MailComposerPresenter!
}

// MARK: - MyRuuviAccountViewOutput

extension MyRuuviAccountPresenter: MyRuuviAccountViewOutput {
    func viewDidLoad() {
        syncViewModel()
    }

    func viewDidTapDeleteButton() {
        guard let email = ruuviUser.email?.lowercased() else { return }
        activityPresenter.show(with: .loading(message: nil))
        Task { [weak self] in
            guard let self else { return }
            do {
                _ = try await ruuviCloud.deleteAccount(email: email)
                activityPresenter.update(with: .success(message: nil))
                view.viewDidShowAccountDeletionConfirmation()
            } catch {
                activityPresenter.update(with: .failed(message: nil))
                errorPresenter.present(error: error)
            }
            activityPresenter.dismiss(immediately: false)
        }
    }

    func viewDidTapSignoutButton() {
        createSignOutAlert()
    }

    func viewDidTriggerClose() {
        router.dismiss()
    }

    func viewDidTriggerSupport(with email: String) {
        mailComposerPresenter.present(email: email.lowercased())
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
        let title = RuuviLocalization.Menu.SignOut.text
        let message = RuuviLocalization.TagsManagerPresenter.SignOutConfirmAlert.message
        let confirmActionTitle = RuuviLocalization.ok
        let cancelActionTitle = RuuviLocalization.cancel
        let confirmAction = UIAlertAction(
            title: confirmActionTitle,
            style: .default
        ) { [weak self] _ in
            guard let sSelf = self else { return }
            sSelf.activityPresenter.show(with: .loading(message: nil))
            Task { [weak sSelf] in
                guard let sSelf else { return }
                do {
                    if let token = sSelf.pnManager.fcmToken, !token.isEmpty {
                        _ = try await sSelf.cloudNotificationService.unregister(token: token, tokenId: nil)
                        sSelf.pnManager.fcmToken = nil
                        sSelf.pnManager.fcmTokenLastRefreshed = nil
                    }
                } catch {
                    // Non-fatal: proceed with logout even if unregister fails
                }
                do {
                    _ = try await sSelf.authService.logout()
                } catch {
                    // Ignore logout error but continue UI state changes
                }
                sSelf.settings.cloudModeEnabled = false
                sSelf.viewDidTriggerClose()
                sSelf.syncViewModel()
                sSelf.reloadWidgets()
                sSelf.activityPresenter.update(with: .success(message: nil))
                sSelf.activityPresenter.dismiss()
            }
        }
        let cancleAction = UIAlertAction(
            title: cancelActionTitle,
            style: .cancel,
            handler: nil
        )
        let actions = [confirmAction, cancleAction]
        let alertViewModel = AlertViewModel(
            title: title,
            message: message,
            style: .alert,
            actions: actions
        )
        alertPresenter.showAlert(alertViewModel)
    }

    private func reloadWidgets() {
        WidgetCenter.shared.reloadTimelines(
            ofKind: AppAssemblyConstants.simpleWidgetKindId
        )
    }
}
