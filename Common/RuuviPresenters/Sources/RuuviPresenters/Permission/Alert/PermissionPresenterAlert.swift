import RuuviLocalization
import UIKit

public final class PermissionPresenterAlert: PermissionPresenter {
    public init() {}

    public func presentNoPhotoLibraryPermission() {
        let message = RuuviLocalization.PermissionPresenter.NoPhotoLibraryAccess.message
        presentAlert(with: message)
    }

    public func presentNoCameraPermission() {
        let message = RuuviLocalization.PermissionPresenter.NoCameraAccess.message
        presentAlert(with: message)
    }

    public func presentNoLocationPermission() {
        let message = RuuviLocalization.PermissionPresenter.NoLocationAccess.message
        presentAlert(with: message)
    }

    public func presentNoPushNotificationsPermission() {
        let message = RuuviLocalization.PermissionPresenter.NoPushNotificationsPermission.message
        presentAlert(with: message)
    }

    private func presentAlert(with message: String) {
        guard let viewController = RuuviPresenterHelper.topViewController() else { return }
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let cancel = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil)
        let actionTitle = RuuviLocalization.PermissionPresenter.settings
        let settings = UIAlertAction(title: actionTitle, style: .default) { _ in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl, options: [:])
            }
        }
        alert.addAction(settings)
        alert.addAction(cancel)
        viewController.present(alert, animated: true)
    }
}
