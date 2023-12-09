import RuuviLocalization
import UIKit

class DevicesTableViewCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // UI
    private lazy var deviceNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorBigTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Montserrat(.bold, size: 14)
        return label
    }()

    private lazy var tokenIdLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Montserrat(.regular, size: 12)
        return label
    }()

    private lazy var lastAccessedLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicatorTextColor
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Montserrat(.regular, size: 12)
        return label
    }()
}

extension DevicesTableViewCell {
    override func prepareForReuse() {
        super.prepareForReuse()
        deviceNameLabel.text = nil
        tokenIdLabel.text = nil
        lastAccessedLabel.text = nil
    }
}

private extension DevicesTableViewCell {
    func setUpUI() {
        backgroundColor = .clear
        selectionStyle = .none

        let container = UIView(color: RuuviColor.dashboardCardBGColor,
                               cornerRadius: 8)
        contentView.addSubview(container)
        container.fillSuperview(padding: .init(top: 4, left: 8, bottom: 4, right: 8))

        let textStack = UIStackView(arrangedSubviews: [
            deviceNameLabel, tokenIdLabel, lastAccessedLabel,
        ])
        textStack.spacing = 4
        textStack.distribution = .fill
        textStack.axis = .vertical

        container.addSubview(textStack)
        textStack.fillSuperview(padding: .init(top: 8, left: 8, bottom: 8, right: 8))
    }
}

extension DevicesTableViewCell {
    func configure(with viewModel: DevicesViewModel) {
        deviceNameLabel.text = viewModel.name.value

        if let tokenId = viewModel.id.value {
            tokenIdLabel.text = "Token Id: " + tokenId.stringValue
        } else {
            tokenIdLabel.text = "Token Id: " + RuuviLocalization.na
        }

        if let lastAccessed = viewModel.lastAccessed.value {
            let date = Date(timeIntervalSince1970: Double(lastAccessed))
            lastAccessedLabel.text = "Last accessed: " +
                AppDateFormatter.shared.ruuviAgoString(from: date)
        } else {
            lastAccessedLabel.text = "Last accessed: " + RuuviLocalization.na
        }
    }
}
