import UIKit

public final class PermissionPresenterAlert: PermissionPresenter {
    public init() {}

    public func presentNoPhotoLibraryPermission() {
        let message = "PermissionPresenter.NoPhotoLibraryAccess.message".localized(for: Self.self)
        presentAlert(with: message)
    }

    public func presentNoCameraPermission() {
        let message = "PermissionPresenter.NoCameraAccess.message".localized(for: Self.self)
        presentAlert(with: message)
    }

    public func presentNoLocationPermission() {
        let message = "PermissionPresenter.NoLocationAccess.message".localized(for: Self.self)
        presentAlert(with: message)
    }

    public func presentNoPushNotificationsPermission() {
        let message = "PermissionPresenter.NoPushNotificationsPermission.message".localized(for: Self.self)
        presentAlert(with: message)
    }

    private func presentAlert(with message: String) {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel".localized(for: Self.self), style: .cancel, handler: nil)
        let actionTitle = "PermissionPresenter.settings".localized(for: Self.self)
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
