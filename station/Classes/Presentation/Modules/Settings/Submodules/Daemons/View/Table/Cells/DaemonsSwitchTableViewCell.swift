import UIKit

protocol DaemonsSwitchTableViewCellDelegate: class {
    func daemonsSwitch(cell: DaemonsSwitchTableViewCell, didChange value: Bool)
}

class DaemonsSwitchTableViewCell: UITableViewCell {

    weak var delegate: DaemonsSwitchTableViewCellDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    
    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.daemonsSwitch(cell: self, didChange: isOnSwitch.isOn)
    }
    
}
