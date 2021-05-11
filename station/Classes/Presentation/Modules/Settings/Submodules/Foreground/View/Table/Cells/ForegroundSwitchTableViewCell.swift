import UIKit

protocol ForegroundSwitchTableViewCellDelegate: AnyObject {
    func foregroundSwitch(cell: ForegroundSwitchTableViewCell, didChange value: Bool)
}

class ForegroundSwitchTableViewCell: UITableViewCell {

    weak var delegate: ForegroundSwitchTableViewCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.foregroundSwitch(cell: self, didChange: isOnSwitch.isOn)
    }

}
