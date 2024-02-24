import UIKit

protocol ChartSettingsSwitchTableViewCellDelegate: AnyObject {
    func chartSettingsSwitch(cell: ChartSettingsSwitchTableViewCell, didChange value: Bool)
}

class ChartSettingsSwitchTableViewCell: UITableViewCell {
    weak var delegate: ChartSettingsSwitchTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: RuuviSwitchView!

    override func awakeFromNib() {
        super.awakeFromNib()
        isOnSwitch.delegate = self
    }
}

// MARK: - RuuviSwitchViewDelegate
extension ChartSettingsSwitchTableViewCell: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
        delegate?.chartSettingsSwitch(cell: self, didChange: isOn)
    }
}
