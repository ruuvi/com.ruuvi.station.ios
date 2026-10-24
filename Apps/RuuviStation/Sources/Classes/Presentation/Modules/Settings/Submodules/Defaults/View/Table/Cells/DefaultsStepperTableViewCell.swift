import RuuviLocalization
import UIKit

protocol DefaultsStepperTableViewCellDelegate: AnyObject {
    func defaultsStepper(cell: DefaultsStepperTableViewCell, didChange value: Int)
}

class DefaultsStepperTableViewCell: UITableViewCell {
    weak var delegate: DefaultsStepperTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var stepper: UIStepper!

    private var unit: DefaultsIntegerUnit = .seconds
    private var item: DefaultItem?
    private var prefix = ""
    private var integerEditor: DefaultsIntegerEditorConfiguration?

    override func awakeFromNib() {
        super.awakeFromNib()
        stepper.layer.cornerRadius = 8
    }

    func configure(with viewModel: DefaultsViewModel) {
        unit = viewModel.unit
        item = viewModel.item.value
        prefix = viewModel.title ?? ""
        integerEditor = viewModel.integerEditor
        accessoryType = integerEditor == nil ? .none : .disclosureIndicator
        selectionStyle = integerEditor == nil ? .none : .default
        configureStepper()
        stepper.value = Double(viewModel.integer.value.bound)
        updateTitle(value: viewModel.integer.value.bound)
        titleLabel.textColor = RuuviColor.menuTextColor.color
        titleLabel.font = .ruuviHeadline()
        stepper.backgroundColor = RuuviColor.tintColor.color
    }

    @IBAction func stepperValueChanged(_: Any) {
        let value = Int(stepper.value)
        updateTitle(value: value)
        delegate?.defaultsStepper(cell: self, didChange: value)
    }

    private func configureStepper() {
        stepper.minimumValue = 1
        stepper.maximumValue = 3600
        if let integerEditor {
            stepper.minimumValue = Double(integerEditor.range.lowerBound)
            stepper.maximumValue = Double(integerEditor.range.upperBound)
            stepper.stepValue = 1
            return
        }
        switch item {
        case .imageCompressionQuality:
            stepper.minimumValue = 10
            stepper.maximumValue = 100
            stepper.stepValue = 10
        case .graphDownsampleMaximumPoints:
            stepper.minimumValue = 1000
            stepper.maximumValue = 5000
            stepper.stepValue = 100
        default:
            switch unit {
            case .hours: stepper.stepValue = 1
            case .minutes: stepper.stepValue = 5
            case .seconds: stepper.stepValue = 30
            case .decimal:
                stepper.minimumValue = 5
                stepper.stepValue = 5
            }
        }
    }

    private func updateTitle(value: Int) {
        if let integerEditor {
            titleLabel.text = "\(prefix) (\(integerEditor.formatValue(value)))\nTap to edit"
            return
        }
        if item == .imageCompressionQuality {
            titleLabel.text = "\(prefix) (\(value)%)"
            return
        }
        let unitString: String = switch unit {
        case .hours: RuuviLocalization.Defaults.Interval.Hour.string
        case .minutes: RuuviLocalization.Defaults.Interval.Min.string
        case .seconds: RuuviLocalization.Defaults.Interval.Sec.string
        case .decimal: ""
        }
        titleLabel.text = unitString.isEmpty ? "\(prefix) (\(value))" : "\(prefix) (\(value) \(unitString))"
    }
}
