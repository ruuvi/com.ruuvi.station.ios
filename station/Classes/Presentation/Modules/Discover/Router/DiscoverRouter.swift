import LightRoute
import BTKit

class DiscoverRouter: DiscoverRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    private lazy var ruuviTagAddTransitioningDelegate = RuuviTagAddTransitioningDelegate()
    
    func open(ruuviTag: RuuviTag) {
        let factory = StoryboardFactory(storyboardName: "RuuviTag")
        try! transitionHandler
            .forStoryboard(factory: factory, to: RuuviTagModuleInput.self)
            .add(transitioningDelegate: ruuviTagAddTransitioningDelegate)
            .apply(to: { (viewController) in
                viewController.modalPresentationStyle = .custom
            })
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag)
            })
    }
}
