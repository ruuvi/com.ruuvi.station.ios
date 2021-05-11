import UIKit

protocol PhotoPickerPresenterDelegate: AnyObject {
    func photoPicker(presenter: PhotoPickerPresenter, didPick photo: UIImage)
}

protocol PhotoPickerPresenter {
    var delegate: PhotoPickerPresenterDelegate? { get set }
    func pick(sourceView: UIView?)
}
