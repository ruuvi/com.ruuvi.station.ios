import UIKit
import RuuviLocalization

protocol DiscoverWebTagsInfoHeaderFooterViewDelegate: AnyObject {
    func discoverWebTagsInfo(headerView: DiscoverWebTagsInfoHeaderFooterView, didTapOnInfo button: UIButton)
}

class DiscoverWebTagsInfoHeaderFooterView: UITableViewHeaderFooterView, Localizable {
    weak var delegate: DiscoverWebTagsInfoHeaderFooterViewDelegate?

    @IBOutlet weak var webTagsLabel: UILabel!
    @IBOutlet weak var noValuesView: UIView!

    override func awakeFromNib() {
        super.awakeFromNib()
        setupLocalization()
    }

    func localize() {
        webTagsLabel.text = "DiscoverTable.SectionTitle.WebTags".localized(for: Self.self).uppercased()
    }

    @IBAction func noValuesButtonTouchUpInside(_ sender: UIButton) {
        delegate?.discoverWebTagsInfo(headerView: self, didTapOnInfo: sender)
    }
}
