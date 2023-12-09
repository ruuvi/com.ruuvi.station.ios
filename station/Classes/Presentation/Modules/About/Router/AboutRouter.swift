import Foundation
import LightRoute
import RuuviLocalization
import UIKit

class AboutRouter: AboutRouterInput {
    weak var transitionHandler: TransitionHandler!

    func dismiss() {
        try! transitionHandler.closeCurrentModule().perform()
    }

    func openChangelogPage() {
        guard let url = URL(string: RuuviLocalization.changelogIosUrl) else {
            return
        }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}
