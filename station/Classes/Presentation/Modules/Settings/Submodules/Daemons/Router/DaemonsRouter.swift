import LightRoute

enum DaemonsEmbedSegue: String {
    case list = "EmbedDaemonsSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedDaemonsTableViewControllerSegueIdentifier"
}

class DaemonsRouter: DaemonsRouterInput {
    weak var transitionHandler: TransitionHandler!
}
