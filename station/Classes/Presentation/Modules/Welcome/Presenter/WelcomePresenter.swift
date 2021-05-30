import Foundation
import RuuviLocal

class WelcomePresenter: WelcomeModuleInput {
    weak var view: WelcomeViewInput!
    var router: WelcomeRouterInput!
    var settings: RuuviLocalSettings!
}

extension WelcomePresenter: WelcomeViewOutput {
    func viewDidTriggerScan() {
        settings.welcomeShown = true
        router.openDiscover()
    }
}
