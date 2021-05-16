import UIKit

protocol AdvancedSwitchTableViewCellDelegate: AnyObject {
    func advancedSwitch(cell: AdvancedSwitchTableViewCell, didChange value: Bool)
}

class AdvancedSwitchTableViewCell: UITableViewCell {

    weak var delegate: AdvancedSwitchTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.advancedSwitch(cell: self, didChange: isOnSwitch.isOn)
    }

}
