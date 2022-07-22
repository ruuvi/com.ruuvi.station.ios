import UIKit

protocol TagSettingsMoreInfoHeaderFooterViewDelegate: AnyObject {
    func tagSettingsMoreInfo(headerView: TagSettingsMoreInfoHeaderFooterView, didTapOnInfo button: UIButton)
}

class TagSettingsMoreInfoHeaderFooterView: UITableViewHeaderFooterView, Localizable {
    weak var delegate: TagSettingsMoreInfoHeaderFooterViewDelegate?

    @IBOutlet weak var noValuesLabel: UILabel!
    @IBOutlet weak var moreInfoLabel: UILabel!
    @IBOutlet weak var noValuesView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
    }

    func localize() {
        noValuesLabel.text = "TagSettings.Label.noValues.text".localized()
        moreInfoLabel.text = "TagSettings.Label.moreInfo.text".localized().uppercased()
    }

    @IBAction func noValuesButtonTouchUpInside(_ sender: UIButton) {
        delegate?.tagSettingsMoreInfo(headerView: self, didTapOnInfo: sender)
    }
}
