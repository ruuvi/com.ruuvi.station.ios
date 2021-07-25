import UIKit

extension UIViewController {
    func showAlert(title: String? = nil,
                   message: String? = nil) {
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(for: Self.self), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}
