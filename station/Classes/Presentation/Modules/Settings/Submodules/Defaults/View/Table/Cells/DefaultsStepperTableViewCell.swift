import UIKit

protocol DefaultsStepperTableViewCellDelegate: AnyObject {
    func defaultsStepper(cell: DefaultsStepperTableViewCell, didChange value: Int)
}

class DefaultsStepperTableViewCell: UITableViewCell {
    weak var delegate: DefaultsStepperTableViewCellDelegate?
    var unit: DefaultsIntegerUnit = .seconds

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    var prefix: String = ""

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        let unitString: String
        switch unit {
        case .hours:
            unitString = "Defaults.Interval.Hour.string".localized()
        case .minutes:
            unitString = "Defaults.Interval.Min.string".localized()
        case .seconds:
            unitString = "Defaults.Interval.Sec.string".localized()
        }
        titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
        delegate?.defaultsStepper(cell: self, didChange: result)
    }
}
