import UIKit

protocol TagSettingsSectionHeaderViewDelegate: AnyObject {
    func didTapSectionHeaderMoreInfo(headerView: TagSettingsSectionHeaderView,
                                     didTapOnInfo button: UIButton)
}

class TagSettingsSectionHeaderView: UITableViewHeaderFooterView, Localizable {
    weak var delegate: TagSettingsSectionHeaderViewDelegate?

    @IBOutlet weak var noValuesLabel: UILabel!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var noValuesView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
    }

    func localize() {
        noValuesLabel.text = "TagSettings.Label.noValues.text".localized()
    }

    @IBAction func noValuesButtonTouchUpInside(_ sender: UIButton) {
        delegate?.didTapSectionHeaderMoreInfo(headerView: self,
                                              didTapOnInfo: sender)
    }
}
