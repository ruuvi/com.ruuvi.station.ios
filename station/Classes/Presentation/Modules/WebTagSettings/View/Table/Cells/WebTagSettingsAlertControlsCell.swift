import UIKit
import RangeSeekSlider

protocol WebTagSettingsAlertControlsCellDelegate: AnyObject {
    func webTagSettingsAlertControls(cell: WebTagSettingsAlertControlsCell,
                                     didEnter description: String?)
    func webTagSettingsAlertControls(cell: WebTagSettingsAlertControlsCell,
                                     didSlideTo minValue: CGFloat,
                                     maxValue: CGFloat)
}

class WebTagSettingsAlertControlsCell: UITableViewCell {
    weak var delegate: WebTagSettingsAlertControlsCellDelegate?

    @IBOutlet weak var slider: RURangeSeekSlider!
    @IBOutlet weak var textField: UITextField!

    private let maxCharsInTextFields = 100

    override func awakeFromNib() {
        super.awakeFromNib()
        slider.delegate = self
    }

}

// MARK: - IBActions
extension WebTagSettingsAlertControlsCell {
    @IBAction func textFieldEditingDidEnd(_ sender: Any) {
        delegate?.webTagSettingsAlertControls(cell: self, didEnter: textField.text)
    }
}

// MARK: - RangeSeekSliderDelegate
extension WebTagSettingsAlertControlsCell: RangeSeekSliderDelegate {
    func rangeSeekSlider(_ slider: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        delegate?.webTagSettingsAlertControls(cell: self, didSlideTo: minValue, maxValue: maxValue)
    }
}

// MARK: - UITextFieldDelegate
extension WebTagSettingsAlertControlsCell: UITextFieldDelegate {
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
