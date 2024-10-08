import RuuviLocalization
import UIKit

protocol DefaultsStepperTableViewCellDelegate: AnyObject {
    func defaultsStepper(cell: DefaultsStepperTableViewCell, didChange value: Int)
}

class DefaultsStepperTableViewCell: UITableViewCell {
    weak var delegate: DefaultsStepperTableViewCellDelegate?
    var unit: DefaultsIntegerUnit = .seconds
    var item: DefaultItem?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var stepper: UIStepper!

    var prefix: String = ""

    override func awakeFromNib() {
        super.awakeFromNib()
        stepper.layer.cornerRadius = 8
    }

    @IBAction func stepperValueChanged(_: Any) {
        let result = Int(stepper.value)
        let unitString: String = switch unit {
        case .hours:
            RuuviLocalization.Defaults.Interval.Hour.string
        case .minutes:
            RuuviLocalization.Defaults.Interval.Min.string
        case .seconds:
            RuuviLocalization.Defaults.Interval.Sec.string
        case .decimal:
            ""
        }
        switch item {
        case .imageCompressionQuality:
            titleLabel.text = prefix + " " + "(" + "\(result)" + "%)"
        default:
            switch unit {
            case .hours, .minutes, .seconds:
                titleLabel.text = prefix + " " + "(" + "\(result)" + " " + unitString + ")"
            case .decimal:
                titleLabel.text = prefix + " " + "(" + "\(result)" + ")"
            }
        }
        delegate?.defaultsStepper(cell: self, didChange: result)
    }
}
