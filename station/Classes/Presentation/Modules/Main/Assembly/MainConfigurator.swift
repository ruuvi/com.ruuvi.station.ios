import UIKit

class MainConfigurator {
    
    func configure(navigationController: UINavigationController) {
        let router = MainRouter.shared
        router.navigationController = navigationController
        router.navigationDelegate = MainNavigationDelegate()
        navigationController.delegate = router.navigationDelegate
        navigationController.view.backgroundColor = .white
        navigationController.interactivePopGestureRecognizer?.isEnabled = false
    }
    
}
