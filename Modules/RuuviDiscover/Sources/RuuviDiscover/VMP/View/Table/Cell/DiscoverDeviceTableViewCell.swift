import UIKit
import RuuviLocalization

class DiscoverDeviceTableViewCell: UITableViewCell {
    @IBOutlet var identifierLabel: UILabel!
    @IBOutlet var rssiImageView: UIImageView!
    @IBOutlet var rssiLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
        rssiLabel.font = UIFont.ruuviBody()
    }
}
