import LightRoute

class DashboardRouter: DashboardRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    private lazy var menuTableTransitioningDelegate = MenuTableTransitioningDelegate()
    
    func openMenu(output: MenuModuleOutput) {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .add(transitioningDelegate: menuTableTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            }).then({ (module) -> Any? in
                module.configure(output: output)
            })
    }
    
    func openDiscover() {
        let factory = StoryboardFactory(storyboardName: "Discover", bundle: .main, restorationId: "DiscoverTableNavigationController")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(isOpenedFromWelcome: false)
            })
    }
}
