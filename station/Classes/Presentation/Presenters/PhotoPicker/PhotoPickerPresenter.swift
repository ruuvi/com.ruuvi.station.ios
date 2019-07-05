import UIKit

protocol PhotoPickerPresenterDelegate: class {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage)
}

protocol PhotoPickerPresenter {
    var delegate: PhotoPickerPresenterDelegate? { get set }
    func pick()
}
