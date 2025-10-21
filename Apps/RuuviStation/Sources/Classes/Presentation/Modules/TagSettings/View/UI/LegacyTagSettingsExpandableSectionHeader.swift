import RuuviLocalization
import RuuviOntology
import UIKit

// swiftlint:disable:next type_name
protocol LegacyTagSettingsExpandableSectionHeaderDelegate: NSObjectProtocol {
    func toggleSection(
        _ header: LegacyTagSettingsExpandableSectionHeader,
        section: Int
    )
    func didTapSectionMoreInfo(headerView: LegacyTagSettingsExpandableSectionHeader)
}

class LegacyTagSettingsExpandableSectionHeader: UIView {
    weak var delegate: LegacyTagSettingsExpandableSectionHeaderDelegate?
    private var section: Int = 0

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.ruuviHeadline()
        return label
    }()

    private lazy var alertIcon: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }()

    lazy var mutedTillLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = RuuviColor.textColor.color.withAlphaComponent(0.7)
        label.font = UIFont.ruuviSubheadline()
        return label
    }()

    lazy var arrowView: UIImageView = {
        let iv = UIImageView()
        iv.backgroundColor = .clear
        iv.image = RuuviAsset.arrowDropDown.image
        iv.tintColor = RuuviColor.tintColor.color
        iv.contentMode = .scaleAspectFit
        return iv
    }()

    private lazy var noValueContainer = UIView(color: .clear)
    private lazy var noValueLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.TagSettings.Label.NoValues.text
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .right
        label.numberOfLines = 0
        label.font = UIFont.ruuviFootnote()
        return label
    }()

    private lazy var iconView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "info.circle")
        iv.tintColor = RuuviColor.tintColor.color
        return iv
    }()

    lazy var seprator = UIView(color: RuuviColor.primary.color)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // swiftlint:disable:next function_body_length
    private func setUpUI() {
        backgroundColor = RuuviColor.tagSettingsSectionHeaderColor.color
        addSubview(titleLabel)
        titleLabel.anchor(
            top: topAnchor,
            leading: safeLeftAnchor,
            bottom: bottomAnchor,
            trailing: nil,
            padding: .init(top: 8, left: 8, bottom: 9, right: 0)
        )

        addSubview(alertIcon)
        alertIcon.size(width: 20, height: 20)
        alertIcon.centerYInSuperview()

        addSubview(mutedTillLabel)
        mutedTillLabel.anchor(
            top: nil,
            leading: alertIcon.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: 0,
                left: 8,
                bottom: 0,
                right: 0
            )
        )
        mutedTillLabel.centerYInSuperview()

        addSubview(arrowView)
        arrowView.anchor(
            top: nil,
            leading: mutedTillLabel.trailingAnchor,
            bottom: nil,
            trailing: safeRightAnchor,
            padding: .init(
                top: 0,
                left: 8,
                bottom: 0,
                right: 12
            ),
            size: .init(width: 14, height: 14)
        )
        arrowView.centerYInSuperview()

        addSubview(seprator)
        seprator.anchor(
            top: nil,
            leading: safeLeftAnchor,
            bottom: bottomAnchor,
            trailing: safeRightAnchor,
            size: .init(width: 0, height: 1)
        )

        let noValueStack = UIStackView(arrangedSubviews: [
            noValueLabel, iconView
        ])
        iconView.size(width: 16, height: 16)
        noValueStack.axis = .horizontal
        noValueStack.spacing = 8
        noValueStack.distribution = .fill

        noValueContainer.addSubview(noValueStack)
        noValueStack.fillSuperview()

        addSubview(noValueContainer)
        noValueContainer.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: arrowView.leadingAnchor,
            padding: .init(top: 0, left: 8, bottom: 0, right: 8)
        )
        noValueContainer.centerYInSuperview()

        noValueContainer.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(tapNoValuesView(_:))
            ))
        addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(tapHeader(_:))
            ))
    }

    @objc private func tapHeader(_ gestureRecognizer: UITapGestureRecognizer) {
        guard let cell = gestureRecognizer.view as? LegacyTagSettingsExpandableSectionHeader
        else {
            return
        }

        delegate?.toggleSection(self, section: cell.section)
    }

    @objc private func tapNoValuesView(_: UITapGestureRecognizer) {
        delegate?.didTapSectionMoreInfo(headerView: self)
    }
}

extension LegacyTagSettingsExpandableSectionHeader {
    func setTitle(with string: String?) {
        titleLabel.text = string
    }

    func setTitle(
        with string: String?,
        section: Int,
        collapsed: Bool,
        backgroundColor: UIColor? = nil,
        font: UIFont?
    ) {
        titleLabel.text = string
        self.section = section
        setCollapsed(collapsed)
        if let color = backgroundColor {
            self.backgroundColor = color
        } else {
            self.backgroundColor = RuuviColor.tagSettingsItemHeaderColor.color
        }
        if let font {
            titleLabel.font = font
        } else {
            titleLabel.font = UIFont.mulish(.bold, size: 16)
        }
    }

    func setCollapsed(_ collapsed: Bool) {
        if collapsed {
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                self?.arrowView.transform = .identity
            })
        } else {
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                self?.arrowView.transform = CGAffineTransform(rotationAngle: .pi)
            })
        }
    }

    func hideSeparator(hide: Bool) {
        seprator.alpha = hide ? 0 : 1
    }

    func hideAlertComponents() {
        alertIcon.image = nil
        mutedTillLabel.text = nil
    }

    func showNoValueView(show: Bool) {
        noValueContainer.isHidden = !show
    }

    func setAlertState(
        with date: Date?,
        isOn: Bool,
        alertState: AlertState?
    ) {
        // Show alert icon only when alert is on
        alertIcon.alpha = isOn ? 1 : 0

        // Show muted label if muted till is not nil
        // If muted till is not nil, we don't have to execute the rest of the code
        if let date, date > Date() {
            mutedTillLabel.isHidden = !isOn
            mutedTillLabel.text = AppDateFormatter
                .shared
                .shortTimeString(from: date)
            alertIcon.image = RuuviAsset.iconAlertOff.image
            alertIcon.tintColor = RuuviColor.logoTintColor.color
            return
        } else {
            mutedTillLabel.isHidden = true
            alertIcon.image = isOn ? RuuviAsset.iconAlertOn.image : nil
            alertIcon.tintColor = RuuviColor.logoTintColor.color
            removeAlertAnimations()
        }

        // Check the state and show alert bell based on the state if alert is on.
        guard isOn, let state = alertState
        else {
            return
        }
        switch state {
        case .registered:
            alertIcon.image = RuuviAsset.iconAlertOn.image
            alertIcon.tintColor = RuuviColor.logoTintColor.color
            removeAlertAnimations()
        case .firing:
            alertIcon.alpha = 1.0
            alertIcon.tintColor = RuuviColor.orangeColor.color
            alertIcon.image = RuuviAsset.iconAlertActive.image
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UIView.animate(
                    withDuration: 0.5,
                    delay: 0,
                    options: [
                        .repeat,
                        .autoreverse,
                    ],
                    animations: { [weak self] in
                        self?.alertIcon.alpha = 0.0
                    }
                )
            }
        default:
            alertIcon.image = nil
            removeAlertAnimations()
        }
    }

    func removeAlertAnimations() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alertIcon.layer.removeAllAnimations()
            self?.alertIcon.alpha = 1
        }
    }
}
