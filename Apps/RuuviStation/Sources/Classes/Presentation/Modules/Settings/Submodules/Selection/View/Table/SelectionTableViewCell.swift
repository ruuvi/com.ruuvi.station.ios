import UIKit

class SelectionTableViewCell: UITableViewCell {
    @IBOutlet var nameLabel: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        nameLabel.trailingAnchor.constraint(
            lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor
        ).isActive = true
    }
}
