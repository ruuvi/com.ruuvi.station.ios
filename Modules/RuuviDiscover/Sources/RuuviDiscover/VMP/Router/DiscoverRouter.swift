// import LightRoute
// import BTKit
// import UIKit
//
// class DiscoverRouter: DiscoverRouterInput {
//    weak var transitionHandler: UIViewController!
//
//    func openCards() {
//        let factory = StoryboardFactory(storyboardName: "Cards")
//        try! transitionHandler
//            .forStoryboard(factory: factory, to: CardsModuleInput.self)
//            .to(preferred: .navigation(style: .push))
//            .perform()
//    }
//
//    func openRuuviWebsite() {
//        UIApplication.shared.open(URL(string: "https://ruuvi.com")!, options: [:], completionHandler: nil)
//    }
//
//    func openLocationPicker(output: LocationPickerModuleOutput) {
//        let factory = StoryboardFactory(storyboardName: "LocationPicker")
//        try! transitionHandler
//            .forStoryboard(factory: factory, to: LocationPickerModuleInput.self)
//            .then({ (module) -> Any? in
//                module.configure(output: output)
//            })
//    }
//
//    func dismiss(completion: (() -> Void)?) {
//        transitionHandler.dismiss(animated: true, completion: completion)
//    }
// }
