import UIKit
import RuuviService
import RuuviLocal
import RuuviUser
import RuuviPresenters

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

    private weak var output: MenuModuleOutput?

    func configure(output: MenuModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss()
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

    func viewDidSelectGetRuuviGateway() {
        output?.menu(module: self, didSelectGetRuuviGateway: nil)
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
}

extension MenuPresenter {

    private func syncViewModel() {
        let viewModel = MenuViewModel()
        if ruuviUser.isAuthorized {
            viewModel.username.value = ruuviUser.email
        }
        self.viewModel = viewModel
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
