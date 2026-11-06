import PhotosUI
import RuuviCore
import RuuviPresenters
import UIKit

class PhotoPickerPresenterSheet: NSObject, PhotoPickerPresenter {
    weak var delegate: PhotoPickerPresenterDelegate?
    var permissionsManager: RuuviCorePermission!
    var permissionPresenter: PermissionPresenter!
    var isCameraAvailable: () -> Bool = { UIImagePickerController.isSourceTypeAvailable(.camera) }
    private var selectionID = UUID()

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
        picker.dismiss(
            animated: true,
            completion: { [weak self] in
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
        selectionID = UUID()
        picker.dismiss(
            animated: true,
            completion: { [weak self] in
                guard let provider = results.first?.itemProvider else { return }
                self?.loadSelectedImage(from: provider)
            })
    }

    func loadSelectedImage(from provider: NSItemProvider) {
        selectionID = UUID()
        let selectionID = selectionID
        guard provider.canLoadObject(ofClass: UIImage.self) else { return }
        provider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
            guard error == nil, let image = object as? UIImage else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.selectionID == selectionID else { return }
                self.delegate?.photoPicker(presenter: self, didPick: image)
            }
        }
    }

}

// MARK: - Private

extension PhotoPickerPresenterSheet {

    private func checkCameraPermission() {
        if permissionsManager.isCameraPermissionGranted {
            showCamera()
        } else {
            permissionsManager.requestCameraPermission { [weak self] granted in
                DispatchQueue.main.async { [weak self] in
                    if granted {
                        self?.showCamera()
                    } else {
                        self?.permissionPresenter.presentNoCameraPermission()
                    }
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
        guard isCameraAvailable() else {
            presentPhotoPicker(from: viewController)
            return
        }
        let vc = UIImagePickerController()
        vc.sourceType = .camera
        vc.delegate = self
        viewController.present(vc, animated: true)
    }
}
