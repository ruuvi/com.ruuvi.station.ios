import UIKit

protocol MainRouterInput {
    func openCards()
}

class MainRouter: MainRouterInput {
    static let shared = MainRouter()
    
    weak var navigationController: UINavigationController!
    var navigationDelegate: MainNavigationDelegate!
    
    func unwindToRoot() {
        if let presented = navigationController.topViewController?.presentedViewController {
            presented.dismiss(animated: true) {
                self.navigationController.popToRootViewController(animated: true)
            }
        } else {
            navigationController.popToRootViewController(animated: true)
        }
    }
    
    func openCards() {
        assert(navigationController.topViewController is WelcomeViewController)
        let view = navigationController.topViewController as! WelcomeViewController
        let presenter = view.output as! WelcomePresenter
        let router = presenter.router
        router?.openCards()
    }
}
