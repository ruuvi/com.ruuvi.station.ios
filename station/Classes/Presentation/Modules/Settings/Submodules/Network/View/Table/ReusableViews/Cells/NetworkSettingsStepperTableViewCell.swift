import UIKit

protocol NetworkSettingsStepperTableViewCellDelegate: AnyObject {
    func foregroundStepper(cell: NetworkSettingsStepperTableViewCell, didChange value: Int)
}

class NetworkSettingsStepperTableViewCell: UITableViewCell {
    weak var delegate: NetworkSettingsStepperTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        setTitle(withValue: result)
        delegate?.foregroundStepper(cell: self, didChange: result)
    }

    func setTitle(withValue value: Int) {
        titleLabel.text = "Foreground.Interval.Every.string".localized()
            + " " + "\(value)" + " "
            + "Foreground.Interval.Min.string".localized()
    }
}
