import UIKit

protocol DefaultsStepperTableViewCellDelegate: class {
    func defaultsStepper(cell: DefaultsStepperTableViewCell, didChange value: Int)
}

class DefaultsStepperTableViewCell: UITableViewCell {
    weak var delegate: DefaultsStepperTableViewCellDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!
    
    var prefix: String = ""
    
    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        titleLabel.text = prefix + " " + "(" + "\(result)" + " " + "Defaults.Interval.Sec.string".localized() + ")"
        delegate?.defaultsStepper(cell: self, didChange: result)
    }
}
