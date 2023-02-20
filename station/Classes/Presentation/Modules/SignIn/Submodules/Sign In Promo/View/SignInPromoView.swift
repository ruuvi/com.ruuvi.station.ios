import UIKit

protocol SignInPromoViewDelegate: NSObjectProtocol {
    func didTapLetsDoButton(sender: SignInPromoView)
}

class SignInPromoView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    weak var delegate: SignInPromoViewDelegate?

    private lazy var container = UIView(color: .clear)

    private lazy var titleStack = UIStackView()
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "why_should_sign_in".localized()
        label.font = UIFont.Montserrat(.extraBold, size: UIDevice.isiPhoneSE() ? 24 : 30)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = "sensors_ownership_and_settings_stored_in_cloud".localized()
        label.font = UIFont.Muli(.semiBoldItalic, size: UIDevice.isiPhoneSE() ? 16 : 20)
        return label
    }()

    private lazy var featuresLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.text = prepareFeatures()
        label.font = UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 12 : 18)
        return label
    }()

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 12 : 18)
        label.attributedText = prepareNote()
        return label
    }()

    private lazy var letsDoButton: UIButton = {
        let button = UIButton(color: RuuviColor.ruuviTintColor,
                              cornerRadius: 25)
        button.setTitle("lets_do_it".localized(),
                        for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: UIDevice.isiPhoneSE() ? 14 : 16)
        button.addTarget(self,
                         action: #selector(handleLetsDoTap),
                         for: .touchUpInside)
        return button
    }()
}

extension SignInPromoView {
    @objc private func handleLetsDoTap() {
        delegate?.didTapLetsDoButton(sender: self)
    }
}

extension SignInPromoView {
    private func setUpUI() {
        setUpTitleView()
        setUpPromoView()
    }

    private func setUpTitleView() {
        addSubview(container)
        container.fillSuperview()

        titleStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel
        ])
        titleStack.axis = .vertical
        titleStack.distribution = .fillProportionally
        titleStack.spacing = UIDevice.isiPhoneSE() ? 16 : 24

        container.addSubview(titleStack)
        titleStack.anchor(top: nil,
                         leading: container.safeLeftAnchor,
                         bottom: nil,
                         trailing: container.safeRightAnchor,
                         padding: .init(top: 0, left: !UIDevice.isTablet() ? 20 : 80,
                                        bottom: 0, right: !UIDevice.isTablet() ? 20 : 80))
        titleStack.topAnchor.constraint(
            greaterThanOrEqualTo: container.safeTopAnchor
        ).isActive = true
    }

    private func setUpPromoView() {

        container.addSubview(featuresLabel)
        featuresLabel.anchor(top: titleStack.bottomAnchor,
                         leading: nil,
                         bottom: nil,
                         trailing: nil,
                             padding: .init(top: UIDevice.isiPhoneSE() ? 20 : 30, left: 0,
                                        bottom: 0, right: 0))

        featuresLabel.centerInSuperview()

        container.addSubview(noteLabel)
        noteLabel.anchor(top: featuresLabel.bottomAnchor,
                         leading: titleStack.leadingAnchor,
                         bottom: nil,
                         trailing: titleStack.trailingAnchor,
                         padding: .init(top: UIDevice.isiPhoneSE() ? 20 : 30, left: 0,
                                        bottom: 0, right: 0))

        container.addSubview(letsDoButton)
        letsDoButton.anchor(top: noteLabel.bottomAnchor,
                               leading: container.safeLeftAnchor,
                               bottom: nil,
                               trailing: container.safeRightAnchor,
                               padding: .init(top: UIDevice.isiPhoneSE() ? 20 : 30,
                                              left: !UIDevice.isTablet() ? 50 : 150,
                                              bottom: 0,
                                              right: !UIDevice.isTablet() ? 50 : 150),
                            size: .init(width: 0, height: 50))
        letsDoButton.bottomAnchor.constraint(
            lessThanOrEqualTo: container.bottomAnchor, constant: 20
        ).isActive = true
    }
}

extension SignInPromoView {
    private func prepareFeatures() -> String {
        return [
            "cloud_stored_ownerships".localized(),
            "cloud_stored_names".localized(),
            "cloud_stored_alerts".localized(),
            "cloud_stored_backgrounds".localized(),
            "cloud_stored_calibration".localized(),
            "cloud_stored_sharing".localized()
        ].joined(separator: "\n")
    }

    private func prepareNote() -> NSMutableAttributedString {
        let text =
            "note".localized() + " " +
            "claim_warning".localized()

        let attrString = NSMutableAttributedString(string: text)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(NSAttributedString.Key.font,
                                value: UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 12 : 18),
                                range: range)

        // Make note bold and orange color
        let makeBoldOrange = "note".localized()
        let boldFont = UIFont.Muli(.bold, size: UIDevice.isiPhoneSE() ? 12 : 18)
        let boldRange = NSString(string: attrString.string).range(of: makeBoldOrange)
        attrString.addAttribute(NSAttributedString.Key.font,
                                value: boldFont,
                                range: boldRange)
        attrString.addAttribute(.foregroundColor,
                                value: RuuviColor.ruuviOrangeColor ?? UIColor.systemOrange,
                                range: boldRange)

        // Make rest of the text white
        let regularRange = NSString(string: attrString.string)
            .range(of: "claim_warning".localized())
        attrString.addAttribute(.foregroundColor,
                                value: UIColor.white,
                                range: regularRange)

        return attrString
    }
}
