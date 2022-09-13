import Foundation
import RuuviUser
import RuuviService
import RuuviPresenters
#if canImport(WidgetKit)
import WidgetKit
#endif

final class MyRuuviAccountPresenter: MyRuuviAccountModuleInput {
    weak var view: MyRuuviAccountViewInput!
    var router: MyRuuviAccountRouterInput!
    var ruuviUser: RuuviUser!
    var authService: RuuviServiceAuth!
    var alertPresenter: AlertPresenter!
    var errorPresenter: ErrorPresenter!
}

// MARK: - MyRuuviAccountViewOutput
extension MyRuuviAccountPresenter: MyRuuviAccountViewOutput {
    func viewDidLoad() {
        syncViewModel()
    }

    func viewDidTapDeleteButton() {
        view.viewDidShowAccountDeletionConfirmation()
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
            viewModel.username.value = ruuviUser.email
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
            sSelf.authService.logout()
                .on(success: { [weak sSelf] _ in
                    sSelf?.viewDidTriggerClose()
                    sSelf?.syncViewModel()
                    sSelf?.reloadWidgets()
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

    private func reloadWidgets() {
        if #available(iOS 14.0, *) {
            WidgetCenter.shared.reloadTimelines(ofKind: "ruuvi.simpleWidget")
        }
    }
}
