import UIKit

class PermissionPresenterAlert: PermissionPresenter {
    func presentNoPhotoLibraryPermission() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let alert = UIAlertController(title: nil, message: "PermissionPresenter.NoPhotoLibraryAccess.message".localized(), preferredStyle: .alert)
        let settings = UIAlertAction(title: "PermissionPresenter.settings".localized(), style: .default) { (action) -> Void in
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
        let alert = UIAlertController(title: nil, message: "PermissionPresenter.NoCameraAccess.message".localized(), preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        let settings = UIAlertAction(title: "PermissionPresenter.settings".localized(), style: .default) { (action) -> Void in
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsUrl, options: [:])
            }
        }
        alert.addAction(settings)
        alert.addAction(cancel)
        viewController.present(alert, animated: true)
    }
}
