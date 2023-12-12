import LightRoute

enum ChartSettingsEmbedSegue: String {
    case list = "EmbedAdvancedSwiftUIHostingControllerSegueIdentifier"
    case table = "EmbedAdvancedTableViewControllerSegueIdentifier"
}

class ChartSettingsRouter: ChartSettingsRouterInput {
    weak var transitionHandler: TransitionHandler!
}
