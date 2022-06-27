import Foundation
import StoreKit
import RuuviLocal

struct AppStoreReviewHelper {
    static func askForReview(settings: RuuviLocalSettings) {
        switch settings.appOpenedCount {
        case settings.appOpenedInitialCountToAskReview:
            SKStoreReviewController.requestReview()
        case _ where settings.appOpenedCount%settings.appOpenedCountDivisibleToAskReview == 0:
            SKStoreReviewController.requestReview()
        default:
            break
        }
    }

    fileprivate func requestReview() {
        SKStoreReviewController.requestReview()
    }
}
