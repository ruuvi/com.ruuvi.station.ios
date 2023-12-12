import UIKit

class PushAlertSelectionTableViewCell: UITableViewCell {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.ruuviTextColor
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 16)
        return label
    }()

    override init(
        style: UITableViewCell.CellStyle,
        reuseIdentifier: String?
    ) {
        super.init(
            style: style,
            reuseIdentifier: reuseIdentifier
        )
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        backgroundColor = .clear
        tintColor = RuuviColor.ruuviTintColor

        addSubview(titleLabel)
        titleLabel.anchor(
            top: safeTopAnchor,
            leading: safeLeftAnchor,
            bottom: safeBottomAnchor,
            trailing: contentView.safeRightAnchor,
            padding: .init(top: 12, left: 20, bottom: 12, right: 8)
        )
    }
}

// MARK: - SETTERS

extension PushAlertSelectionTableViewCell {
    func configure(title: String?, selection: String?) {
        titleLabel.text = title

        let isSelected = title == selection
        titleLabel.font = isSelected ?
            UIFont.Muli(.bold, size: 16) :
            UIFont.Muli(.regular, size: 16)
        titleLabel.textColor = isSelected ?
            RuuviColor.ruuviMenuTextColor :
            RuuviColor.ruuviTextColor
        accessoryType = isSelected ? .checkmark : .none
    }
}
