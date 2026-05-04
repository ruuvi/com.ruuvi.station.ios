import Foundation
import RuuviLocal
import StoreKit
import UIKit

enum AppStoreReviewHelper {
    static func askForReview(settings: RuuviLocalSettings) {
        let appOpenedCount = settings.appOpenedCount
        guard shouldAskForReview(
            appOpenedCount: appOpenedCount,
            initialCount: settings.appOpenedInitialCountToAskReview,
            divisibleCount: settings.appOpenedCountDivisibleToAskReview,
            lastRequestCount: settings.appStoreReviewLastRequestAppOpenedCount
        ) else { return }
        guard let scene = activeForegroundWindowScene() else { return }

        settings.appStoreReviewLastRequestAppOpenedCount = appOpenedCount
        requestReview(in: scene)
    }

    static func shouldAskForReview(
        appOpenedCount: Int,
        initialCount: Int,
        divisibleCount: Int,
        lastRequestCount: Int
    ) -> Bool {
        guard appOpenedCount > 1 else { return false }
        guard appOpenedCount != lastRequestCount else { return false }

        if initialCount > 1, appOpenedCount == initialCount {
            return true
        }

        guard divisibleCount > 1 else { return false }
        return appOpenedCount % divisibleCount == 0
    }

    fileprivate static func activeForegroundWindowScene() -> UIWindowScene? {
        UIApplication.shared.connectedScenes.first(where: {
            $0.activationState == .foregroundActive
        }) as? UIWindowScene
    }

    fileprivate static func requestReview(in scene: UIWindowScene) {
        SKStoreReviewController.requestReview(in: scene)
    }
}
