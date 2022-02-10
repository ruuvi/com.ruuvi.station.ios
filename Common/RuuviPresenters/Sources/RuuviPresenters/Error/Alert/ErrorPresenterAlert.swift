import UIKit
import RuuviBundleUtils

public final class ErrorPresenterAlert: ErrorPresenter {
    public init() {
        // Intentionally unimplemented
    }
    public func present(error: Error) {
        presentAlert(error: error)
    }
    private func presentAlert(error: Error) {
        var title: String? = "ErrorPresenterAlert.Error".localized(for: Self.self)
        if let localizedError = error as? LocalizedError {
            title = localizedError.failureReason ?? "ErrorPresenterAlert.Error".localized(for: Self.self)
        }
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        let action = UIAlertAction(
            title: "ErrorPresenterAlert.OK".localized(for: Self.self),
            style: .cancel,
            handler: nil
        )
        alert.addAction(action)
        let group = DispatchGroup()
        DispatchQueue.main.async {
            group.enter()
            let topViewController = UIApplication.shared.topViewController()
            var fireAfter: DispatchTimeInterval = .milliseconds(0)
            if topViewController is ActivityRuuviLogoViewController {
                fireAfter = .milliseconds(750)
            }
            group.leave()
            group.notify(queue: .main) { [weak self] in
                self?.provideHapticFeedback(fireAfter, alert: alert)
            }
        }
    }
    private func provideHapticFeedback(_ fireAfter: DispatchTimeInterval, alert: UIAlertController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + fireAfter) {
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.error)
            feedback.prepare()
            UIApplication.shared.topViewController()?.present(alert, animated: true)
        }
    }
}
