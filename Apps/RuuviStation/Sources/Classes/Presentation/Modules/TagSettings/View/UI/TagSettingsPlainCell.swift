import RuuviLocalization
import UIKit

/// Leading title label and trailing aligned value label
/// with an optional label in middle for any additional value.
/// This cell is used for more info section.
class TagSettingsPlainCell: UITableViewCell {
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 14)
        return label
    }()

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .right
        label.numberOfLines = 1
        label.font = UIFont.Muli(.regular, size: 14)
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

        let stack = UIStackView(arrangedSubviews: [
            titleLabel, noteLabel, valueLabel
        ])
        stack.spacing = 8
        stack.distribution = .fill
        stack.axis = .horizontal
        addSubview(stack)
        stack.anchor(
            top: safeTopAnchor,
            leading: safeLeftAnchor,
            bottom: safeBottomAnchor,
            trailing: safeRightAnchor,
            padding: .init(top: 8, left: 8, bottom: 8, right: 12)
        )
    }

    func configure(
        title: String?,
        value: String?,
        note: String? = nil,
        noteColor: UIColor? = nil
    ) {
        titleLabel.text = title
        valueLabel.text = value
        noteLabel.text = note
        noteLabel.textColor = noteColor
    }

    func configure(
        value: String?,
        note: String? = nil,
        noteColor: UIColor? = nil
    ) {
        valueLabel.text = value
        noteLabel.text = note
        noteLabel.textColor = noteColor
    }

    func configure(
        note: String? = nil,
        noteColor: UIColor? = nil
    ) {
        noteLabel.text = note
        noteLabel.textColor = noteColor
    }
}
