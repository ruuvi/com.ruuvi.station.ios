import UIKit

// swiftlint:disable:next type_name
protocol ChartSettingsStepperTableViewCellDelegate: AnyObject {
    func chartSettingsStepper(cell: ChartSettingsStepperTableViewCell, didChange value: Int)
}

class ChartSettingsStepperTableViewCell: UITableViewCell {
    weak var delegate: ChartSettingsStepperTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    var prefix: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        stepper.layer.cornerRadius = 8
    }

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        let unitString: String = result > 1 ? "Interval.Days.string".localized() : "Interval.Day.string".localized()
        titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
        delegate?.chartSettingsStepper(cell: self, didChange: result)
    }
}
