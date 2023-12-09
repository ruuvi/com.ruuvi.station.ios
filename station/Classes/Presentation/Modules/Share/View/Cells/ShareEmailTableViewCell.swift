import UIKit
protocol ShareEmailTableViewCellDelegate: AnyObject {
    func didTapUnshare(for email: String)
}

class ShareEmailTableViewCell: UITableViewCell {
    @IBOutlet var emailLabel: UILabel!
    @IBOutlet var unshareButton: UIButton!

    weak var delegate: ShareEmailTableViewCellDelegate?

    @IBAction func didTapUnshareButton(_: UIButton) {
        guard let email = emailLabel.text else {
            return
        }
        delegate?.didTapUnshare(for: email)
    }
}
