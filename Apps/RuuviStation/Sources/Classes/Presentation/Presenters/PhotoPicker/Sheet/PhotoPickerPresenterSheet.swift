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

    /// Shows the system camera. While the app shares the screen with other apps (iPad windows,
    /// Split View, Slide Over), the system may not allow camera capture, and
    /// `UIImagePickerController` has no multitasking camera opt-in. Its system camera UI then stays
    /// cancellable and the photo library remains the way to pick a photo. Where there is no camera
    /// at all (e.g. a Mac running the iPad app), presenting a camera picker would raise an
    /// exception, so the photo library opens instead.
    private func showCamera() {
        guard let viewController = UIApplication.shared.topViewController() else { return }
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            presentPhotoPicker(from: viewController)
            return
        }
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        viewController.present(vc, animated: true)
    }
}
