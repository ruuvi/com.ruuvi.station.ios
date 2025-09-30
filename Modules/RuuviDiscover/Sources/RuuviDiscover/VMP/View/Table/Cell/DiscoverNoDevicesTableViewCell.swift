import UIKit
import RuuviLocalization

class DiscoverNoDevicesTableViewCell: UITableViewCell {
    // MARK: - UI Components

    let descriptionLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
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
        selectionStyle = .none

        contentView.addSubview(descriptionLabel)

        NSLayoutConstraint.activate([
            descriptionLabel.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 16
            ),
            descriptionLabel.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -18
            ),
            descriptionLabel.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor
            ),
            descriptionLabel.topAnchor.constraint(
                greaterThanOrEqualTo: contentView.topAnchor,
                constant: 8
            ),
            descriptionLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: contentView.bottomAnchor,
                constant: -8
            ),
        ])
    }

    private func applyStyle() {
        descriptionLabel.font = UIFont.ruuviHeadline()
        descriptionLabel.textColor = RuuviColor.menuTextColor.color
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        descriptionLabel.text = nil
    }
}
