import UIKit

protocol TagSettingsAlertHeaderCellDelegate: class {
    func tagSettingsAlertHeader(cell: TagSettingsAlertHeaderCell, didToggle isOn: Bool)
}

class TagSettingsAlertHeaderCell: UITableViewCell {
    weak var delegate: TagSettingsAlertHeaderCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: UILabel!
}

// MARK: - IBActions
extension TagSettingsAlertHeaderCell {

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.tagSettingsAlertHeader(cell: self, didToggle: isOnSwitch.isOn)
    }
}
