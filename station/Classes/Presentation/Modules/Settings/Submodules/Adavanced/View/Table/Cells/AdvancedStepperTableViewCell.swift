import UIKit

protocol AdvancedStepperTableViewCellDelegate: class {
    func advancedStepper(cell: AdvancedStepperTableViewCell, didChange value: Int)
}

class AdvancedStepperTableViewCell: UITableViewCell {
    weak var delegate: AdvancedStepperTableViewCellDelegate?
    var unit: AdvancedIntegerUnit = .seconds

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    var prefix: String = ""

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        let unitString: String
        switch unit {
        case .hours:
            unitString = "Advanced.Interval.Hour.string".localized()
        case .minutes:
            unitString = "Advanced.Interval.Min.string".localized()
        case .seconds:
            unitString = "Advanced.Interval.Sec.string".localized()
        }
        titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
        delegate?.advancedStepper(cell: self, didChange: result)
    }
}
