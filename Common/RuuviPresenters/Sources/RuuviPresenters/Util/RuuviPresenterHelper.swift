import UIKit

struct RuuviPresenterHelper {
    public static func topViewController() -> UIViewController? {
        if var topController = keyWindow()?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
        return nil
    }

    private static func keyWindow() -> UIWindow? {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })
    }
}
