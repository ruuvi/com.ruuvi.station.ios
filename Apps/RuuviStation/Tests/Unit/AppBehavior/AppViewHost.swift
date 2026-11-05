import UIKit
import XCTest

@MainActor final class AppViewHost {
    let window: UIWindow
    let navigation: UINavigationController
    private let previous: UIWindow?
    private let animationsEnabled = UIView.areAnimationsEnabled
    init(_ view: UIViewController, withBackStack: Bool = false) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        UIView.setAnimationsEnabled(false)
        previous = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        navigation = UINavigationController()
        navigation.setViewControllers(withBackStack ? [UIViewController(), view] : [view], animated: false)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        view.loadViewIfNeeded()
        view.view.layoutIfNeeded()
    }
    func close() {
        navigation.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
        previous?.makeKeyAndVisible()
        UIView.setAnimationsEnabled(animationsEnabled)
    }
}
