import UIKit

protocol DefaultsSwitchTableViewCellDelegate: AnyObject {
    func defaultsSwitch(cell: DefaultsSwitchTableViewCell, didChange value: Bool)
}

class DefaultsSwitchTableViewCell: UITableViewCell {
    weak var delegate: DefaultsSwitchTableViewCellDelegate?

    @IBOutlet var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: RuuviSwitchView!

    override func awakeFromNib() {
        super.awakeFromNib()
        isOnSwitch.delegate = self
    }
}

// MARK: - RuuviSwitchViewDelegate
extension DefaultsSwitchTableViewCell: RuuviSwitchViewDelegate {
    func didChangeSwitchState(sender: RuuviSwitchView, didToggle isOn: Bool) {
        delegate?.defaultsSwitch(cell: self, didChange: isOn)
    }
}
