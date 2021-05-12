import UIKit

protocol TagSettingsAlertHeaderCellDelegate: AnyObject {
    func tagSettingsAlertHeader(cell: TagSettingsAlertHeaderCell, didToggle isOn: Bool)
}

class TagSettingsAlertHeaderCell: UITableViewCell {
    weak var delegate: TagSettingsAlertHeaderCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var mutedTillLabel: UILabel!
    @IBOutlet weak var mutedTillImageView: UIImageView!
}

// MARK: - IBActions
extension TagSettingsAlertHeaderCell {

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.tagSettingsAlertHeader(cell: self, didToggle: isOnSwitch.isOn)
    }
}
