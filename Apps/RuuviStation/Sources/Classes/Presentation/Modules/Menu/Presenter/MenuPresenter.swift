import RuuviLocal
import RuuviPresenters
import RuuviService
import RuuviUser
import UIKit
#if canImport(WidgetKit)
    import WidgetKit
#endif

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

    private weak var output: MenuModuleOutput?

    func configure(output: MenuModuleOutput) {
        self.output = output
    }

    func dismiss() {
        router.dismiss()
    }
}

extension MenuPresenter: MenuViewOutput {
    func viewWillAppear() {}

    var userIsAuthorized: Bool {
        ruuviUser.isAuthorized
    }

    var userEmail: String? {
        ruuviUser.email?.lowercased()
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

    func viewDidSelectWhatToMeasure() {
        output?.menu(module: self, didSelectWhatToMeasure: nil)
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
            output?.menu(module: self, didSelectOpenMyRuuviAccount: nil)
        } else {
            output?.menu(module: self, didSelectSignIn: nil)
        }
    }
}
