import UIKit

class ActivityPresenterRuuviLogo: ActivityPresenter {

    var counter = 0
    let window = UIWindow(frame: UIScreen.main.bounds)
    let hudViewController: ActivityRuuviLogoViewController
    weak var appWindow: UIWindow?

    init() {
        // swiftlint:disable force_cast
        hudViewController = UIStoryboard(name: "ActivityRuuviLogo",
                                         bundle: .main)
            .instantiateViewController(withIdentifier: "ActivityRuuviLogoViewController")
            as! ActivityRuuviLogoViewController
        // swiftlint:enable force_cast
        window.windowLevel = .normal
        hudViewController.view.translatesAutoresizingMaskIntoConstraints = false
        window.rootViewController = hudViewController
    }

    func increment() {
        counter += 1
        if counter == 1 {
            show()
        }
    }

    func decrement() {
        counter -= 1
        if counter == 0 {
            hide()
        }
    }

    private func show() {
        appWindow = UIApplication.shared.keyWindow
        window.makeKeyAndVisible()
        hudViewController.spinnerView.animate()
    }

    private func hide() {
        appWindow?.makeKeyAndVisible()
        appWindow = nil
        window.isHidden = true
        hudViewController.spinnerView.stopAnimating()
    }
}
