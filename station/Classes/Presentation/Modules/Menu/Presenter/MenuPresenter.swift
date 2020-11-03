import Foundation

class MenuPresenter: MenuModuleInput {
    weak var view: MenuViewInput!
    var router: MenuRouterInput!
    var userApi: RuuviNetworkUserApi!
    var keychainService: KeychainService!

    private weak var output: MenuModuleOutput?

    func configure(output: MenuModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss()
    }
}

extension MenuPresenter: MenuViewOutput {
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
            output?.menu(module: self, didSelectOpenConfig: nil)
        } else {
            output?.menu(module: self, didSelectSignIn: nil)
        }
    }
}
