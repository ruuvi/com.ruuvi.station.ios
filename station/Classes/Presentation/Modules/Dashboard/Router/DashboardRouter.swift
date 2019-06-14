import LightRoute

class DashboardRouter: DashboardRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    private lazy var menuTableTransitioningDelegate = MenuTableTransitioningDelegate()
    
    func openMenu() {
        let factory = StoryboardFactory(storyboardName: "Menu")
        try! transitionHandler
            .forStoryboard(factory: factory, to: MenuModuleInput.self)
            .add(transitioningDelegate: menuTableTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            }).perform()
    }
}
