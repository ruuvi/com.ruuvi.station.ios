import LightRoute

class AboutRouter: AboutRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openChangelogPage() {
        guard let url = URL(string: "changelog_ios_url".localized()) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
