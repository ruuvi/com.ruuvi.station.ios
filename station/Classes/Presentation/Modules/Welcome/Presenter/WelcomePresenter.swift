import Foundation

class WelcomePresenter: WelcomeModuleInput {
    weak var view: WelcomeViewInput!
    var router: WelcomeRouterInput!
    var settings: Settings!
}

extension WelcomePresenter: WelcomeViewOutput {
    func viewDidTriggerScan() {
        settings.welcomeShown = true
        router.openDiscover()
    }
}
