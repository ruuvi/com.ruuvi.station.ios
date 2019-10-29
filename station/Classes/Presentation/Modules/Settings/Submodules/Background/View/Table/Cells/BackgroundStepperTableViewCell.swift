import UIKit

enum BackgroundStepperUnit {
    case seconds
    case minutes
}

protocol BackgroundStepperTableViewCellDelegate: class {
    func backgroundStepper(cell: BackgroundStepperTableViewCell, didChange value: Int)
}

class BackgroundStepperTableViewCell: UITableViewCell {
    weak var delegate: BackgroundStepperTableViewCellDelegate?
    
    var unit: BackgroundStepperUnit = .minutes
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var stepper: UIStepper!
    
    @IBAction func stepperValueChanged(_ sender: Any) {
        let result = Int(stepper.value)
        switch unit {
        case .minutes:
            titleLabel.text = "Background.Interval.Every.string".localized() + " " + "\(result)" + " " + "Background.Interval.Min.string".localized()
        case .seconds:
            titleLabel.text = "Background.Interval.Every.string".localized() + " " + "\(result)" + " " + "Background.Interval.Sec.string".localized()
        }
        
        delegate?.backgroundStepper(cell: self, didChange: result)
    }
}
