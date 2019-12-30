import LightRoute

enum ForegroundEmbedSegue: String {
    case list = "EmbedForegroundSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedForegroundTableViewControllerSegueIdentifier"
}

class ForegroundRouter: ForegroundRouterInput {
    weak var transitionHandler: TransitionHandler!
}
