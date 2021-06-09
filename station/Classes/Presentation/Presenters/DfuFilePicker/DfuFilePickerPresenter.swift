import UIKit

protocol DfuFilePickerPresenterDelegate: AnyObject {
    func dfuFilePicker(presenter: DfuFilePickerPresenter, didPick fileUrl: URL)
}

protocol DfuFilePickerPresenter {
    var delegate: DfuFilePickerPresenterDelegate? { get set }
    func pick(sourceView: UIView?)
}
