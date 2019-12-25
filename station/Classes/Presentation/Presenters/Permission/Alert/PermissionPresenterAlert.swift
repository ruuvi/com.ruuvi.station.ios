import UIKit

class PermissionPresenterAlert: PermissionPresenter {

    func presentNoPhotoLibraryPermission() {
        let message = "PermissionPresenter.NoPhotoLibraryAccess.message".localized()
        presentAlert(with: message)
    }

    func presentNoCameraPermission() {
        let message = "PermissionPresenter.NoCameraAccess.message".localized()
        presentAlert(with: message)
    }

    func presentNoLocationPermission() {
        let message = "PermissionPresenter.NoLocationAccess.message".localized()
        presentAlert(with: message)
    }

    func presentNoPushNotificationsPermission() {
        let message = "PermissionPresenter.NoPushNotificationsPermission.message".localized()
        presentAlert(with: message)
    }

    private func presentAlert(with message: String) {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        let actionTitle = "PermissionPresenter.settings".localized()
        let settings = UIAlertAction(title: actionTitle, style: .default) { _ -> Void in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl, options: [:])
            }
        }
        alert.addAction(settings)
        alert.addAction(cancel)
        viewController.present(alert, animated: true)
    }
}
