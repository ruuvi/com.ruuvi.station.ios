import LightRoute

class MenuRouter: MenuRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
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
