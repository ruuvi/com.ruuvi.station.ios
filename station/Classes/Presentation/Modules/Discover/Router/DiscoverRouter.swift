import LightRoute
import BTKit

class DiscoverRouter: DiscoverRouterInput {
    weak var transitionHandler: TransitionHandler!
    
    func open(ruuviTag: RuuviTag) {
        let factory = StoryboardFactory(storyboardName: "RuuviTag")
        try! transitionHandler
            .forStoryboard(factory: factory, to: RuuviTagModuleInput.self)
            .then({ (module) -> Any? in
                module.configure(ruuviTag: ruuviTag)
            })
    }
}
