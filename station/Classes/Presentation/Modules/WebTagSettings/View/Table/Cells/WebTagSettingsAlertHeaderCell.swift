import UIKit

protocol WebTagSettingsAlertHeaderCellDelegate: class {
    func webTagSettingsAlertHeader(cell: WebTagSettingsAlertHeaderCell, didToggle isOn: Bool)
}

class WebTagSettingsAlertHeaderCell: UITableViewCell {
    weak var delegate: WebTagSettingsAlertHeaderCellDelegate?

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var isOnSwitch: UISwitch!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var mutedTillLabel: UILabel!
    @IBOutlet weak var mutedTillImageView: UIImageView!
}

// MARK: - IBActions
extension WebTagSettingsAlertHeaderCell {

    @IBAction func isOnSwitchValueChanged(_ sender: Any) {
        delegate?.webTagSettingsAlertHeader(cell: self, didToggle: isOnSwitch.isOn)
    }
}
