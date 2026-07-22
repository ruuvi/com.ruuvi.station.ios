import LightRoute

enum HeartbeatEmbedSegue: String {
    case table = "EmbedHeartbeatTableViewControllerSegueIdentifier"
}

class HeartbeatRouter: HeartbeatRouterInput {
    weak var transitionHandler: TransitionHandler!
}
