import UIKit
import XCTest
@testable import station

@MainActor final class AppViewHost {
    let window: UIWindow
    let navigation: UINavigationController
    private let previous: UIWindow?
    private let animationsEnabled = UIView.areAnimationsEnabled
    init(_ view: UIViewController, withBackStack: Bool = false) throws {
        let scene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .first { $0.delegate is SceneDelegate })
        UIView.setAnimationsEnabled(false)
        previous = scene.windows.first(where: \.isKeyWindow)
        window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        navigation = UINavigationController()
        navigation.setViewControllers(withBackStack ? [UIViewController(), view] : [view], animated: false)
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        navigation.view.layoutIfNeeded()
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
