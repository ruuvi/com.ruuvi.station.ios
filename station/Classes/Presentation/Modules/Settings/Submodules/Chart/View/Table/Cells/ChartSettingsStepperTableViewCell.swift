import UIKit

protocol ChartSettingsStepperTableViewCellDelegate: AnyObject {
    func chartSettingsStepper(cell: ChartSettingsStepperTableViewCell, didChange value: Int)
}

class ChartSettingsStepperTableViewCell: UITableViewCell {
    weak var delegate: ChartSettingsStepperTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    var prefix: String = ""

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        let unitString: String = result > 1 ? "Interval.Days.string".localized() : "Interval.Day.string".localized()
        titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
        delegate?.chartSettingsStepper(cell: self, didChange: result)
    }
}
