import Foundation
import RuuviLocal
import StoreKit

enum AppStoreReviewHelper {
    static func askForReview(settings: RuuviLocalSettings) {
        switch settings.appOpenedCount {
        case settings.appOpenedInitialCountToAskReview:
            requestReview()
        case _ where settings.appOpenedCount % settings.appOpenedCountDivisibleToAskReview == 0:
            requestReview()
        default:
            break
        }
    }

    fileprivate static func requestReview() {
        if let scene = UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
