import LightRoute

class WelcomeRouter: WelcomeRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func openDiscover() {
        let factory = StoryboardFactory(storyboardName: "Discover")
        try! transitionHandler
            .forStoryboard(factory: factory, to: DiscoverModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(isOpenedFromWelcome: true, output: nil)
            })
    }
    
    func openCards() {
        let factory = StoryboardFactory(storyboardName: "Cards")
        try! transitionHandler
            .forStoryboard(factory: factory, to: CardsModuleInput.self)
            .transition(animate: false)
            .to(preferred: .navigation(style: .push))
            .perform()
    }
}
