import UIKit

protocol ForegroundStepperTableViewCellDelegate: class {
    func foregroundStepper(cell: ForegroundStepperTableViewCell, didChange value: Int)
}

class ForegroundStepperTableViewCell: UITableViewCell {
    weak var delegate: ForegroundStepperTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!

    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        if result > 0 {
            titleLabel.text = "Foreground.Interval.Every.string".localized()
            + " " + "\(result)" + " "
            + "Foreground.Interval.Min.string".localized()
        } else {
            titleLabel.text = "Foreground.Interval.All.string".localized()
        }
        delegate?.foregroundStepper(cell: self, didChange: result)
    }
}
