import UIKit
import Localize_Swift

class ErrorPresenterAlert: ErrorPresenter {
    func present(error: Error) {
        if let ruError = error as? RUError {
            switch ruError {
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
        DispatchQueue.main.async {
            alert.show()
        }
    }
}
