import UIKit
import Localize_Swift

class ErrorPresenterAlert: ErrorPresenter {
    // swiftlint:disable:next cyclomatic_complexity
    func present(error: Error) {
        if let ruError = error as? RUError {
            switch ruError {
            case .ruuviLocal(let error):
                presentAlert(error: error)
            case .ruuviPool(let error):
                presentAlert(error: error)
            case .ruuviPersistence(let error):
                presentAlert(error: error)
            case .ruuviStorage(let error):
                presentAlert(error: error)
            case .ruuviService(let error):
                presentAlert(error: error)
            case .btkit(let error):
                presentAlert(error: error)
            case .bluetooth(let error):
                presentAlert(error: error)
            case .core(let error):
                presentAlert(error: error)
            case .persistence(let error):
                presentAlert(error: error)
            case .networking(let error):
                presentAlert(error: error)
            case .parse(let error):
                presentAlert(error: error)
            case .map(let error):
                presentAlert(error: error)
            case .expected(let error):
                presentAlert(error: error)
            case .unexpected(let error):
                presentAlert(error: error)
            case .writeToDisk(let error):
                presentAlert(error: error)
            case .userApi(let error):
                presentAlert(error: error)
            case .dfuError(let error):
                presentAlert(error: error)
            }
        } else {
            presentAlert(error: error)
        }
    }

    private func presentAlert(error: Error) {
        var title: String? = "ErrorPresenterAlert.Error".localized()
        if let localizedError = error as? LocalizedError {
            title = localizedError.failureReason ?? "ErrorPresenterAlert.Error".localized()
        }
        let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
        let action = UIAlertAction(title: "ErrorPresenterAlert.OK".localized(), style: .cancel, handler: nil)
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
            group.notify(queue: .main) {
                DispatchQueue.main.asyncAfter(deadline: .now() + fireAfter) {
                    let feedback = UINotificationFeedbackGenerator()
                    feedback.notificationOccurred(.error)
                    feedback.prepare()
                    UIApplication.shared.topViewController()?.present(alert, animated: true)
                }
            }
        }
    }
}
