import UIKit
import RangeSeekSlider

protocol TagSettingsAlertControlsCellDelegate: class {
    func tagSettingsAlertControls(cell: TagSettingsAlertControlsCell, didEnter description: String?)
    func tagSettingsAlertControls(cell: TagSettingsAlertControlsCell, didSlideTo minValue: CGFloat, maxValue: CGFloat)
}

class TagSettingsAlertControlsCell: UITableViewCell {
    weak var delegate: TagSettingsAlertControlsCellDelegate?

    @IBOutlet weak var slider: RURangeSeekSlider!
    @IBOutlet weak var textField: UITextField!

    private let maxCharsInTextFields = 100

    override func awakeFromNib() {
        super.awakeFromNib()
        slider.delegate = self
    }

}

// MARK: - IBActions
extension TagSettingsAlertControlsCell {
    @IBAction func textFieldEditingDidEnd(_ sender: Any) {
        delegate?.tagSettingsAlertControls(cell: self, didEnter: textField.text)
    }
}

// MARK: - RangeSeekSliderDelegate
extension TagSettingsAlertControlsCell: RangeSeekSliderDelegate {
    func rangeSeekSlider(_ slider: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        delegate?.tagSettingsAlertControls(cell: self, didSlideTo: minValue, maxValue: maxValue)
    }
}

// MARK: - UITextFieldDelegate
extension TagSettingsAlertControlsCell: UITextFieldDelegate {
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
