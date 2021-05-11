import UIKit

protocol WebTagSettingsAlertsHeaderFooterViewDelegate: AnyObject {
    func webTagSettingsAlerts(headerView: WebTagSettingsAlertsHeaderFooterView,
                              didTapOnDisabled button: UIButton)
}

class WebTagSettingsAlertsHeaderFooterView: UITableViewHeaderFooterView, Localizable {
    weak var delegate: WebTagSettingsAlertsHeaderFooterViewDelegate?

    @IBOutlet weak var disabledLabel: UILabel!
    @IBOutlet weak var alertsLabel: UILabel!
    @IBOutlet weak var disabledView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
    }

    func localize() {
        disabledLabel.text = "WebTagSettings.Label.disabled.text".localized()
        alertsLabel.text = "WebTagSettings.Label.alerts.text".localized()
    }

    @IBAction func disabledButtonTouchUpInside(_ sender: UIButton) {
        delegate?.webTagSettingsAlerts(headerView: self, didTapOnDisabled: sender)
    }
}
