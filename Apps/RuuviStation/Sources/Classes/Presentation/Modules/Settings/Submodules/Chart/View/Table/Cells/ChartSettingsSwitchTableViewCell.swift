import UIKit

protocol ChartSettingsSwitchTableViewCellDelegate: AnyObject {
    func chartSettingsSwitch(cell: ChartSettingsSwitchTableViewCell, didChange value: Bool)
}

class ChartSettingsSwitchTableViewCell: UITableViewCell {
    weak var delegate: ChartSettingsSwitchTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var isOnSwitch: UISwitch!

    @IBAction func isOnSwitchValueChanged(_: Any) {
        delegate?.chartSettingsSwitch(cell: self, didChange: isOnSwitch.isOn)
    }
}
