import UIKit

protocol ChartSettingsSwitchTableViewCellDelegate: AnyObject {
    func chartSettingsSwitch(cell: ChartSettingsSwitchTableViewCell, didChange value: Bool)
}

class ChartSettingsSwitchTableViewCell: UITableViewCell {

    weak var delegate: ChartSettingsSwitchTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.chartSettingsSwitch(cell: self, didChange: isOnSwitch.isOn)
    }

}
