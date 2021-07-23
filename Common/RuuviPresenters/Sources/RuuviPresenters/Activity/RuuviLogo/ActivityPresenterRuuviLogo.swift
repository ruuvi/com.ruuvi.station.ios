import UIKit
import RuuviBundleUtils

public final class ActivityPresenterRuuviLogo: ActivityPresenter {
    var counter = 0 {
        didSet {
            switch counter {
            case 0:
                hide()
            case 1:
                show()
            default:
                return
            }
        }
    }
    let minAnimationTime: CFTimeInterval = 0.75
    var startTime: CFTimeInterval?
    let window = UIWindow(frame: UIScreen.main.bounds)
    let hudViewController: ActivityRuuviLogoViewController
    weak var appWindow: UIWindow?

    public init() {
        // swiftlint:disable force_cast
        hudViewController = UIStoryboard.named("ActivityRuuviLogo", for: Self.self)
            .instantiateViewController(withIdentifier: "ActivityRuuviLogoViewController")
            as! ActivityRuuviLogoViewController
        // swiftlint:enable force_cast
        window.windowLevel = .normal
        hudViewController.view.translatesAutoresizingMaskIntoConstraints = false
        window.rootViewController = hudViewController
    }

    public func increment() {
        counter += 1
    }

    public func decrement() {
        guard counter > 0 else {
            return
        }
        counter -= 1
    }

    private func show() {
        startTime = CFAbsoluteTimeGetCurrent()
        appWindow = UIWindow.key
        window.makeKeyAndVisible()
        hudViewController.spinnerView.animate()
    }

    private func hide() {
        let executionTime = CFAbsoluteTimeGetCurrent() - (startTime ?? 0)
        let additionalWaitTime = executionTime < minAnimationTime ? (minAnimationTime - executionTime) : 0
        DispatchQueue.main.asyncAfter(deadline: .now() + additionalWaitTime) {
            self.appWindow?.makeKeyAndVisible()
            self.appWindow = nil
            self.window.isHidden = true
            self.hudViewController.spinnerView.stopAnimating()
        }
    }
}
