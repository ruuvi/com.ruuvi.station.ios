import LightRoute

enum BackgroundEmbedSegue: String {
    case list = "EmbedBackgroundSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedBackgroundTableViewControllerSegueIdentifier"
}

class BackgroundRouter: BackgroundRouterInput {
    weak var transitionHandler: TransitionHandler!
}
