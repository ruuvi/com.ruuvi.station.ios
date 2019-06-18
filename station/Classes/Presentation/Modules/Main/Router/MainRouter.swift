import UIKit

protocol MainRouterInput {
    func openDashboard()
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
    
    func openDashboard() {
        assert(navigationController.topViewController is WelcomeViewController)
        let view = navigationController.topViewController as! WelcomeViewController
        let presenter = view.output as! WelcomePresenter
        let router = presenter.router
        router?.openDashboard()
    }
}
