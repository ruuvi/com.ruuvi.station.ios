import MobileCoreServices
import RuuviCore
import RuuviPresenters
import UIKit

class PhotoPickerPresenterSheet: NSObject, PhotoPickerPresenter {
    weak var delegate: PhotoPickerPresenterDelegate?
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!

    func showLibrary() {
        checkPhotoLibraryPermission()
    }

    func showCameraUI() {
        checkCameraPermission()
    }
}

// MARK: - UIImagePickerControllerDelegate

extension PhotoPickerPresenterSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any])
    {
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
    private func checkPhotoLibraryPermission() {
        if permissionsManager.isPhotoLibraryPermissionGranted {
            showPhotoLibrary()
        } else {
            permissionsManager.requestPhotoLibraryPermission { [weak self] granted in
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
            permissionsManager.requestCameraPermission { [weak self] granted in
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
