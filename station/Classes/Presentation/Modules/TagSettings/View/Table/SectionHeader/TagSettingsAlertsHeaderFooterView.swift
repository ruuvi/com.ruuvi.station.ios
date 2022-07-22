import UIKit

protocol TagSettingsAlertsHeaderFooterViewDelegate: AnyObject {
    func tagSettingsAlerts(headerView: TagSettingsAlertsHeaderFooterView, didTapOnDisabled button: UIButton)
}

class TagSettingsAlertsHeaderFooterView: UITableViewHeaderFooterView, Localizable {
    weak var delegate: TagSettingsAlertsHeaderFooterViewDelegate?

    @IBOutlet weak var disabledLabel: UILabel!
    @IBOutlet weak var alertsLabel: UILabel!
    @IBOutlet weak var disabledView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
    }

    func localize() {
        disabledLabel.text = "TagSettings.Label.disabled.text".localized()
        alertsLabel.text = "TagSettings.Label.alerts.text".localized().uppercased()
    }

    @IBAction func disabledButtonTouchUpInside(_ sender: UIButton) {
        delegate?.tagSettingsAlerts(headerView: self, didTapOnDisabled: sender)
    }
}
