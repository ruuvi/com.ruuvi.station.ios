import UIKit

class PhotoPickerPresenterSheet: NSObject, PhotoPickerPresenter {
    weak var delegate: PhotoPickerPresenterDelegate?
    var permissionsManager: PermissionsManager!
    var permissionPresenter: PermissionPresenter!
    
    func pick() {
        showSourceDialog()
    }
}

// MARK: - UIImagePickerControllerDelegate
extension PhotoPickerPresenterSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let photo = info[.originalImage] as? UIImage {
            delegate?.photoPicker(presenter: self, didPick: photo)
        }
    }
}

// MARK: - Private
extension PhotoPickerPresenterSheet {
    
    private func showSourceDialog() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let sheet = UIAlertController(title: nil, message: "PhotoPicker.Sheet.message".localized(), preferredStyle: .actionSheet)
        let library = UIAlertAction(title: "PhotoPicker.Sheet.library".localized(), style: .default) { [weak self] (action) in
            self?.checkPhotoLibraryPermission()
        }
        let camera = UIAlertAction(title: "PhotoPicker.Sheet.camera".localized(), style: .default) { [weak self] (action) in
            self?.checkCameraPermission()
        }
        let cancel = UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil)
        sheet.addAction(library)
        sheet.addAction(camera)
        sheet.addAction(cancel)
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
