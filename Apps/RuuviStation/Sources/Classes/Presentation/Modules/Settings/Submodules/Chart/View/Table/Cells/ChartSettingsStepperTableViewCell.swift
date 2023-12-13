import RuuviLocalization
import UIKit

// swiftlint:disable:next type_name
protocol ChartSettingsStepperTableViewCellDelegate: AnyObject {
    func chartSettingsStepper(cell: ChartSettingsStepperTableViewCell, didChange value: Int)
}

class ChartSettingsStepperTableViewCell: UITableViewCell {
    weak var delegate: ChartSettingsStepperTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var stepper: UIStepper!

    var prefix: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        stepper.layer.cornerRadius = 8
    }

    @IBAction func stepperValueChanged(_: Any) {
        let result = Int(stepper.value)
        let unitString: String = result > 1
            ? RuuviLocalization.Interval.Days.string
            : RuuviLocalization.Interval.Day.string
        titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
        delegate?.chartSettingsStepper(cell: self, didChange: result)
    }
}
