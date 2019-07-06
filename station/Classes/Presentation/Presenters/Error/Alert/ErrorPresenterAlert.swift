import UIKit
import Localize_Swift

class ErrorPresenterAlert: ErrorPresenter {
    func present(error: Error) {
        if let ruError = error as? RUError {
            switch ruError {
            case .core(let error):
                presentAlert(error: error)
            case .persistence(let error):
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
        alert.show()
    }
}
