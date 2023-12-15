import RuuviLocalization
import UIKit

extension UIViewController {
    func showAlert(
        title: String? = nil,
        message: String? = nil
    ) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}
