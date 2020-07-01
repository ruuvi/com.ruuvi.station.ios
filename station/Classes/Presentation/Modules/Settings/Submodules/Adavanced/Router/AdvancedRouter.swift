import LightRoute

enum AdvancedEmbedSegue: String {
    case list = "EmbedAdvancedSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedAdvancedTableViewControllerSegueIdentifier"
}

class AdvancedRouter: AdvancedRouterInput {
    weak var transitionHandler: TransitionHandler!

    func openNetworkSettings() {
        let factory = StoryboardFactory(storyboardName: "NetworkSettings")
        try! transitionHandler
            .forStoryboard(factory: factory, to: NetworkSettingsModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ module in
                module.configure()
            })
    }
}
