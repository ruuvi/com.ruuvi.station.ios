import UIKit

protocol DefaultsSwitchTableViewCellDelegate: AnyObject {
    func defaultsSwitch(cell: DefaultsSwitchTableViewCell, didChange value: Bool)
}

class DefaultsSwitchTableViewCell: UITableViewCell {
    weak var delegate: DefaultsSwitchTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var isOnSwitch: UISwitch!

    @IBAction func isOnSwitchValueChanged(_: Any) {
        delegate?.defaultsSwitch(cell: self, didChange: isOnSwitch.isOn)
    }
}
