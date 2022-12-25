import UIKit

class TagSettingsFooterCell: UITableViewCell {

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = .secondaryLabel
        label.font = UIFont.Muli(.regular, size: 12)
        return label
    }()

    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style,
                   reuseIdentifier: reuseIdentifier)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    fileprivate func setUpUI() {
        backgroundColor = .clear
        addSubview(noteLabel)
        noteLabel.fillSuperviewToSafeArea(padding: .init(top: 4, left: 10, bottom: 4, right: 8))
    }

    func configure(value: String?) {
        noteLabel.text = value
    }
}
