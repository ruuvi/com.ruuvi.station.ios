import Foundation
import StoreKit
import RuuviLocal

struct AppStoreReviewHelper {
    static func askForReview(settings: RuuviLocalSettings) {
        switch settings.appOpenedCount {
        case 50:
            SKStoreReviewController.requestReview()
        case _ where settings.appOpenedCount%100 == 0:
            SKStoreReviewController.requestReview()
        default:
            break
        }
    }

    fileprivate func requestReview() {
        SKStoreReviewController.requestReview()
    }
}
