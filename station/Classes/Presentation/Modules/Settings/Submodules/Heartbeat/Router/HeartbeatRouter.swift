import LightRoute

enum HeartbeatEmbedSegue: String {
    case list = "EmbedHeartbeatSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedHeartbeatTableViewControllerSegueIdentifier"
}

class HeartbeatRouter: HeartbeatRouterInput {
    weak var transitionHandler: TransitionHandler!
}
