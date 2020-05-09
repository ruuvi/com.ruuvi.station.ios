import UIKit

class KaltiotPickerTableViewCell: UITableViewCell {
    @IBOutlet weak var iconImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!

    func configure(with model: KaltiotBeaconViewModel) {
        nameLabel.text = model.beacon.id
        nameLabel.isEnabled = model.isConnectable
        iconImageView.isHidden = !model.isConnectable
    }
}
