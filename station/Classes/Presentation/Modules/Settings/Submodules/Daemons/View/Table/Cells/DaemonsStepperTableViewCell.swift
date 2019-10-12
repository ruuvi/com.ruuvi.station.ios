import UIKit

protocol DaemonsStepperTableViewCellDelegate: class {
    func daemonsStepper(cell: DaemonsStepperTableViewCell, didChange value: Int)
}

class DaemonsStepperTableViewCell: UITableViewCell {
    weak var delegate: DaemonsStepperTableViewCellDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!
    
    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        titleLabel.text = "Daemons.Interval.Every.string".localized() + " " + "\(result)" + " " + "Daemons.Interval.Min.string".localized()
        delegate?.daemonsStepper(cell: self, didChange: result)
    }
}
