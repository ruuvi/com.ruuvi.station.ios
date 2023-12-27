import RuuviLocalization
import UIKit

public final class ErrorPresenterAlert: ErrorPresenter {
    public init() {}

    public func present(error: Error) {
        presentAlert(error: error)
    }

    private func presentAlert(error: Error) {
        var title: String? = RuuviLocalization.ErrorPresenterAlert.error
        if let localizedError = error as? LocalizedError {
            title = localizedError.failureReason ?? RuuviLocalization.ErrorPresenterAlert.error
        }
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        let action = UIAlertAction(
            title: RuuviLocalization.ErrorPresenterAlert.ok,
            style: .cancel,
            handler: nil
        )
        alert.addAction(action)
        let group = DispatchGroup()
        DispatchQueue.main.async {
            group.enter()
            group.leave()
            group.notify(queue: .main) {
                DispatchQueue.main.async {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.error)
                    feedback.prepare()
                    RuuviPresenterHelper.topViewController()?.present(alert, animated: true)
                }
            }
        }
    }
}
