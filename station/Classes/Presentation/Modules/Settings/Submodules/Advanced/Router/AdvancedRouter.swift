import LightRoute

enum AdvancedEmbedSegue: String {
    case list = "EmbedAdvancedSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedAdvancedTableViewControllerSegueIdentifier"
}

class AdvancedRouter: AdvancedRouterInput {
    weak var transitionHandler: TransitionHandler!
}
