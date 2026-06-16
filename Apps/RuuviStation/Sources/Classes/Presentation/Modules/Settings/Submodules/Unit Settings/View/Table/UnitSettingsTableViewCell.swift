import UIKit

class UnitSettingsTableViewCell: UITableViewCell {
    @IBOutlet var titleLbl: UILabel!
    @IBOutlet var valueLbl: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()

        titleLbl.numberOfLines = 1
        titleLbl.lineBreakMode = .byTruncatingTail
        titleLbl.setContentCompressionResistancePriority(.required, for: .horizontal)

        valueLbl.numberOfLines = 1
        valueLbl.lineBreakMode = .byTruncatingTail
        valueLbl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        titleLbl.trailingAnchor.constraint(
            lessThanOrEqualTo: valueLbl.leadingAnchor,
            constant: -12
        ).isActive = true
    }
}
