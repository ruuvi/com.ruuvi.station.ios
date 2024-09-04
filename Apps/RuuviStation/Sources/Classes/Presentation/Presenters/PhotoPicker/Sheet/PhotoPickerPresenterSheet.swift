import PhotosUI
import RuuviCore
import RuuviPresenters
import UIKit

class PhotoPickerPresenterSheet: NSObject, PhotoPickerPresenter {
    weak var delegate: PhotoPickerPresenterDelegate?
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!

    func showLibrary() {
        showPhotoLibrary()
    }

    func showCameraUI() {
        checkCameraPermission()
    }
}

// MARK: - UIImagePickerControllerDelegate

extension PhotoPickerPresenterSheet: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let sSelf = self else { return }
            if let photo = info[.originalImage] as? UIImage {
                sSelf.delegate?.photoPicker(presenter: sSelf, didPick: photo)
            }
        })
    }
}

// MARK: - PHPickerViewControllerDelegate

extension PhotoPickerPresenterSheet: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true, completion: { [weak self] in
            guard let sSelf = self else { return }
            guard let result = results.first else { return }

            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                    guard error == nil else {
                        return
                    }
                    if let image = object as? UIImage {
                        DispatchQueue.main.async {
                            sSelf.delegate?.photoPicker(presenter: sSelf, didPick: image)
                        }
                    }
                }
            }
        })
    }
}

// MARK: - Private

extension PhotoPickerPresenterSheet {

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
        presentPhotoPicker(from: viewController)
    }

    private func presentPhotoPicker(from viewController: UIViewController) {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .current

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        viewController.present(picker, animated: true, completion: nil)
    }

    private func showCamera() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        viewController.present(vc, animated: true)
    }
}
