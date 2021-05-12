import UIKit
protocol ShareEmailTableViewCellDelegate: AnyObject {
    func didTapUnshare(for email: String)
}
class ShareEmailTableViewCell: UITableViewCell {
    @IBOutlet weak var emailLabel: UILabel!
    @IBOutlet weak var unshareButton: UIButton!

    weak var delegate: ShareEmailTableViewCellDelegate?

    @IBAction func didTapUnshareButton(_ sender: UIButton) {
        guard let email = emailLabel.text else {
            return
        }
        delegate?.didTapUnshare(for: email)
    }
}
