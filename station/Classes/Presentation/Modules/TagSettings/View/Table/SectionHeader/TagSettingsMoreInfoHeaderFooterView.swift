import UIKit

protocol TagSettingsMoreInfoHeaderFooterViewDelegate: class {
    func tagSettingsMoreInfo(headerView: TagSettingsMoreInfoHeaderFooterView, didTapOnInfo button: UIButton)
}

class TagSettingsMoreInfoHeaderFooterView: UITableViewHeaderFooterView {
    weak var delegate: TagSettingsMoreInfoHeaderFooterViewDelegate?
    
    @IBOutlet weak var noValuesView: UIView!
    
    @IBAction func noValuesButtonTouchUpInside(_ sender: UIButton) {
        delegate?.tagSettingsMoreInfo(headerView: self, didTapOnInfo: sender)
    }
}
