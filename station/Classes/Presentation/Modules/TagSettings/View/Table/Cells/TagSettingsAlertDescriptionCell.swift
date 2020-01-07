import UIKit

protocol TagSettingsAlertDescriptionCellDelegate: class {
    func tagSettingsAlertDescription(cell: TagSettingsAlertDescriptionCell, didEnter description: String?)
}
class TagSettingsAlertDescriptionCell: UITableViewCell {
    weak var delegate: TagSettingsAlertDescriptionCellDelegate?

    @IBOutlet weak var textField: UITextField!

    private let maxCharsInTextFields = 100
}

// MARK: - IBActions
extension TagSettingsAlertDescriptionCell {
    @IBAction func textFieldEditingDidEnd(_ sender: Any) {
        delegate?.tagSettingsAlertDescription(cell: self, didEnter: textField.text)
    }
}

// MARK: - UITextFieldDelegate
extension TagSettingsAlertDescriptionCell: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textField(_ textField: UITextField,
                   shouldChangeCharactersIn range: NSRange,
                   replacementString string: String) -> Bool {
        guard let newText = textField.text?.replace(with: string, in: range) else { return false }
        return newText.count <= maxCharsInTextFields
    }
}
