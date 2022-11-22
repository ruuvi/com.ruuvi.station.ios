import UIKit

protocol TagSettingsAlertHeaderCellDelegate: AnyObject {
    func tagSettingsAlertHeader(cell: TagSettingsAlertHeaderCell,
                                didToggle isOn: Bool)
}

class TagSettingsAlertHeaderCell: UITableViewCell {
    // Public
    weak var delegate: TagSettingsAlertHeaderCellDelegate?

    // Private
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.numberOfLines = 0
        label.textColor = .label
        label.font = .systemFont(ofSize: 17)
        return label
    }()

    lazy var alertStateImageView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .clear
        iv.image = UIImage(named: "icon-alert-off")
        iv.contentMode = .scaleAspectFit
        iv.tintColor = .label
        return iv
    }()

    lazy var mutedTillLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .darkGray
        label.font = .systemFont(ofSize: 14)
        return label
    }()

    lazy private var isExpandedSwitch = RUAlertExpandButton()

    private var isExpanded: Bool = false
    // Init
    override init(style: UITableViewCell.CellStyle,
                  reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setUpUI()
    }

    // Lifecycle
    override func awakeFromNib() {
        super.awakeFromNib()
        isExpandedSwitch.delegate = self
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        isExpandedSwitch.delegate = nil
    }
}

extension TagSettingsAlertHeaderCell {
    // swiftlint:disable:next function_body_length
    private func setUpUI() {
        backgroundColor = .none

        addSubview(titleLabel)
        titleLabel.anchor(top: topAnchor,
                          leading: leadingAnchor,
                          bottom: bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 8,
                                         left: 18,
                                         bottom: 8,
                                         right: 0))

        addSubview(alertStateImageView)
        alertStateImageView.anchor(top: nil,
                                  leading: nil,
                                  bottom: nil,
                                  trailing: nil,
                                  padding: .init(top: 0,
                                                 left: 8,
                                                 bottom: 0,
                                                 right: 0),
                                  size: .init(width: 18, height: 20))
        alertStateImageView.centerYInSuperview()

        addSubview(mutedTillLabel)
        mutedTillLabel.anchor(top: nil,
                              leading: alertStateImageView.trailingAnchor,
                              bottom: nil,
                              trailing: nil,
                              padding: .init(top: 0,
                                             left: 8,
                                             bottom: 0,
                                             right: 0))
        mutedTillLabel.centerYInSuperview()

        addSubview(isExpandedSwitch)
        isExpandedSwitch.anchor(top: nil,
                                leading: mutedTillLabel.trailingAnchor,
                                bottom: nil,
                                trailing: trailingAnchor,
                                padding: .init(top: 0,
                                               left: 8,
                                               bottom: 0,
                                               right: 12),
                                size: .init(width: 32, height: 32))
        isExpandedSwitch.centerYInSuperview()
    }
}

// MARK: - CustomExpandButtonDelegate
extension TagSettingsAlertHeaderCell: RUAlertExpandButtonDelegate {
    func didTapButton(sender: RUAlertExpandButton, expanded: Bool) {
        isExpanded = expanded
        delegate?.tagSettingsAlertHeader(cell: self, didToggle: expanded)
    }
}

// MARK: Public setter
extension TagSettingsAlertHeaderCell {
    func toggle() {
        isExpandedSwitch.toggle()
    }
}
