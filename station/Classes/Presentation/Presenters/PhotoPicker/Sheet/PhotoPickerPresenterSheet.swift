import UIKit

class PhotoPickerPresenterSheet: NSObject, PhotoPickerPresenter {
    weak var delegate: PhotoPickerPresenterDelegate?
    var permissionsManager: PermissionsManager!
    var permissionPresenter: PermissionPresenter!
    var sourceView: UIView?

    func pick(sourceView: UIView?) {
        self.sourceView = sourceView
        showSourceDialog()
    }
}

// MARK: - UIImagePickerControllerDelegate
extension PhotoPickerPresenterSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let sSelf = self else { return }
            if let photo = info[.originalImage] as? UIImage {
                sSelf.delegate?.photoPicker(presenter: sSelf, didPick: photo)
            }
        })
    }
}

// MARK: - Private
extension PhotoPickerPresenterSheet {

    private func showSourceDialog() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let sheet = UIAlertController(title: nil, message: "PhotoPicker.Sheet.message".localized(), preferredStyle: .actionSheet)
        let library = UIAlertAction(title: "PhotoPicker.Sheet.library".localized(), style: .default) { [weak self] (_) in
            self?.checkPhotoLibraryPermission()
        }
        let camera = UIAlertAction(title: "PhotoPicker.Sheet.camera".localized(), style: .default) { [weak self] (_) in
            self?.checkCameraPermission()
        }
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        sheet.addAction(library)
        sheet.addAction(camera)
        sheet.addAction(cancel)
        if let presenter = sheet.popoverPresentationController {
            presenter.sourceView = sourceView
            if let bounds = sourceView?.bounds {
                presenter.sourceRect = bounds
            }
            presenter.permittedArrowDirections = .up
        }
        viewController.present(sheet, animated: true)
    }

    private func checkPhotoLibraryPermission() {
        if permissionsManager.isPhotoLibraryPermissionGranted {
            showPhotoLibrary()
        } else {
            permissionsManager.requestPhotoLibraryPermission { [weak self] (granted) in
                if granted {
                    self?.showPhotoLibrary()
                } else {
                    self?.permissionPresenter.presentNoPhotoLibraryPermission()
                }
            }
        }
    }

    private func checkCameraPermission() {
        if permissionsManager.isCameraPermissionGranted {
            showCamera()
        } else {
            permissionsManager.requestCameraPermission { [weak self] (granted) in
                if granted {
                    self?.showCamera()
                } else {
                    self?.permissionPresenter.presentNoCameraPermission()
                }
            }
        }
    }

    private func showPhotoLibrary() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let vc = UIImagePickerController()
        vc.sourceType = .photoLibrary
        vc.delegate = self
        viewController.present(vc, animated: true)
    }

    private func showCamera() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        viewController.present(vc, animated: true)
    }

}
