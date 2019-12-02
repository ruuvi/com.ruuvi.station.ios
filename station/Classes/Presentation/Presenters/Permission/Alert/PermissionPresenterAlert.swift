import UIKit

class PermissionPresenterAlert: PermissionPresenter {
    func presentNoPhotoLibraryPermission() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let message = "PermissionPresenter.NoPhotoLibraryAccess.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let actionTitle = "PermissionPresenter.settings".localized()
        let settings = UIAlertAction(title: actionTitle, style: .default) { _ -> Void in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl, options: [:])
            }
        }
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        alert.addAction(settings)
        alert.addAction(cancel)
        viewController.present(alert, animated: true)
    }

    func presentNoCameraPermission() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let message = "PermissionPresenter.NoCameraAccess.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        let actionTitle = "PermissionPresenter.settings".localized()
        let settings = UIAlertAction(title: actionTitle, style: .default) { (_) -> Void in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl, options: [:])
            }
        }
        alert.addAction(settings)
        alert.addAction(cancel)
        viewController.present(alert, animated: true)
    }

    func presentNoLocationPermission() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let message = "PermissionPresenter.NoLocationAccess.message".localized()
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

    func presentNoPushNotificationsPermission() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let message = "PermissionPresenter.NoPushNotificationsPermission.message".localized()
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
