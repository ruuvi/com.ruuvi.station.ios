import LightRoute

enum DefaultsEmbedSegue: String {
    case list = "EmbedDefaultsSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedDefaultsTableViewControllerSegueIdentifier"
}

class DefaultsRouter: DefaultsRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }
}
