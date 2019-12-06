import UIKit
import RangeSeekSlider

protocol TagSettingsAlertSliderCellDelegate: class {
    func tagSettingsAlertSlider(cell: TagSettingsAlertSliderCell, didToggle isOn: Bool)
    func tagSettingsAlertSlider(cell: TagSettingsAlertSliderCell, didEnter description: String?)
    func tagSettingsAlertSlider(cell: TagSettingsAlertSliderCell, didSlideTo minValue: CGFloat, maxValue: CGFloat)
}

class TagSettingsAlertSliderCell: UITableViewCell, Localizable {
    weak var delegate: TagSettingsAlertSliderCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var slider: RURangeSeekSlider!
    @IBOutlet weak var textField: UITextField!

    private let maxCharsInTextFields = 100

    override func awakeFromNib() {
        super.awakeFromNib()
        slider.delegate = self
        setupLocalization()
    }

    func localize() {
        textField.placeholder = "TagSettings.TemperatureAlert.Description.placeholder".localized()
    }
}

// MARK: - IBActions
extension TagSettingsAlertSliderCell {
    @IBAction func textFieldEditingDidEnd(_ sender: Any) {
        delegate?.tagSettingsAlertSlider(cell: self, didEnter: textField.text)
    }

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.tagSettingsAlertSlider(cell: self, didToggle: isOnSwitch.isOn)
    }
}

// MARK: - RangeSeekSliderDelegate
extension TagSettingsAlertSliderCell: RangeSeekSliderDelegate {
    func rangeSeekSlider(_ slider: RangeSeekSlider, didChange minValue: CGFloat, maxValue: CGFloat) {
        delegate?.tagSettingsAlertSlider(cell: self, didSlideTo: minValue, maxValue: maxValue)
    }
}

// MARK: - UITextFieldDelegate
extension TagSettingsAlertSliderCell: UITextFieldDelegate {
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
