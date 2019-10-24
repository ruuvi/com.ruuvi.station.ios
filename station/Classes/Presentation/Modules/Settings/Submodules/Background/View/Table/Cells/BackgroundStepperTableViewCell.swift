import UIKit

protocol BackgroundStepperTableViewCellDelegate: class {
    func backgroundStepper(cell: BackgroundStepperTableViewCell, didChange value: Int)
}

class BackgroundStepperTableViewCell: UITableViewCell {
    weak var delegate: BackgroundStepperTableViewCellDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!
    
    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        titleLabel.text = "Background.Interval.Every.string".localized() + " " + "\(result)" + " " + "Background.Interval.Min.string".localized()
        delegate?.backgroundStepper(cell: self, didChange: result)
    }
}
