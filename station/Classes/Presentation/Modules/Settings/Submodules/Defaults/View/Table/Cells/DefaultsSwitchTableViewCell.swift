import UIKit

protocol DefaultsSwitchTableViewCellDelegate: class {
    func defaultsSwitch(cell: DefaultsSwitchTableViewCell, didChange value: Bool)
}

class DefaultsSwitchTableViewCell: UITableViewCell {

    weak var delegate: DefaultsSwitchTableViewCellDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    
    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.defaultsSwitch(cell: self, didChange: isOnSwitch.isOn)
    }
    
}
