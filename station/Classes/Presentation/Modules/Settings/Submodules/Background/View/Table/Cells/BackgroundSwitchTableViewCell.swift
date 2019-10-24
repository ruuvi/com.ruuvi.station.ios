import UIKit

protocol BackgroundSwitchTableViewCellDelegate: class {
    func backgroundSwitch(cell: BackgroundSwitchTableViewCell, didChange value: Bool)
}

class BackgroundSwitchTableViewCell: UITableViewCell {

    weak var delegate: BackgroundSwitchTableViewCellDelegate?
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    
    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.backgroundSwitch(cell: self, didChange: isOnSwitch.isOn)
    }
    
}
