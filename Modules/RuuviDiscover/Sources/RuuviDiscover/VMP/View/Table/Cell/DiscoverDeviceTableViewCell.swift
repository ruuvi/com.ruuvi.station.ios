import RuuviLocalization
import UIKit

class DiscoverDeviceTableViewCell: UITableViewCell {
    // MARK: - UI Components

    let identifierLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    let rssiImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    let rssiLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        label.setContentCompressionResistancePriority(
            .required,
            for: .vertical
        )
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        applyStyle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupViews() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        contentView.addSubview(identifierLabel)
        contentView.addSubview(rssiLabel)
        contentView.addSubview(rssiImageView)

        NSLayoutConstraint.activate([
            identifierLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),
            identifierLabel.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),
            identifierLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: rssiLabel.leadingAnchor,
                constant: -8
            ),

            rssiImageView.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -16
            ),
            rssiImageView.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),
            rssiImageView.widthAnchor.constraint(equalToConstant: 20),
            rssiImageView.heightAnchor.constraint(equalToConstant: 18),

            rssiLabel.trailingAnchor.constraint(
                equalTo: rssiImageView.leadingAnchor,
                constant: -8
            ),
            rssiLabel.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),
        ])
    }

    private func applyStyle() {
        identifierLabel.font = UIFont.ruuviHeadline()
        identifierLabel.textColor = RuuviColor.menuTextColor.color

        rssiLabel.font = UIFont.ruuviSubheadline()
        rssiLabel.textColor = UIColor(white: 0.33, alpha: 1.0)
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        identifierLabel.text = nil
        rssiLabel.text = nil
        rssiImageView.image = nil
    }
}
