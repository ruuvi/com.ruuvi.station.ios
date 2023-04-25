import Foundation
import UIKit

class SignInBenefitsViewController: UIViewController, SignInBenefitsViewInput {

    // Configuration
    var output: SignInBenefitsViewOutput?

    // UI Componenets starts
    private lazy var closeButton: UIBarButtonItem = {
        let button = UIBarButtonItem(image: RuuviAssets.closeButtonImage,
                                     style: .plain,
                                     target: self,
                                     action: #selector(handleCloseButtonTap))
        button.tintColor = .white
        return button
    }()

    private lazy var bgLayer: UIImageView = {
        let iv = UIImageView(image: RuuviAssets.signInBgLayer)
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.showsVerticalScrollIndicator = false
        return sv
    }()

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
        label.font = UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 16 : 18)
        return label
    }()

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 16 : 18)
        label.attributedText = prepareNote()
        return label
    }()

    private lazy var continueButton: UIButton = {
        let button = UIButton(color: RuuviColor.ruuviTintColor,
                              cornerRadius: 25)
        button.setTitle("sign_in_continue".localized(),
                        for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 16)
        button.addTarget(self,
                         action: #selector(handleContinueTap),
                         for: .touchUpInside)
        return button
    }()

    private lazy var signInOptionalLabel: UILabel = {
        let label = UILabel()
        label.text = "signing_in_is_optional".localized()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 16 : 18)
        return label
    }()

}

// MARK: - VIEW LIFE CYCLE
extension SignInBenefitsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.makeTransparent()
    }
}

extension SignInBenefitsViewController {
    @objc fileprivate func handleCloseButtonTap() {
        output?.viewDidTapClose()
    }

    @objc private func handleContinueTap() {
        output?.viewDidTapContinue()
    }
}

extension SignInBenefitsViewController {
    func localize() {
        // No op.
    }
}

// MARK: - PRIVATE UI SETUP
extension SignInBenefitsViewController {
    private func setUpUI() {
        setUpNavBarView()
        setUpBase()
        setUpSignInPromoView()
    }

    fileprivate func setUpNavBarView() {
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setUpBase() {
        view.backgroundColor = RuuviColor.ruuviPrimary

        view.addSubview(bgLayer)
        bgLayer.fillSuperview()

        view.addSubview(scrollView)
        scrollView.fillSuperviewToSafeArea()
    }

    // swiftlint:disable:next function_body_length
    private func setUpSignInPromoView() {
        scrollView.addSubview(container)
        container.fillSuperview()
        container.widthAnchor.constraint(equalTo: view.widthAnchor).isActive = true
        container.centerInSuperview()

        titleStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel
        ])
        titleStack.axis = .vertical
        titleStack.distribution = .fillProportionally
        titleStack.spacing = UIDevice.isiPhoneSE() ? 16 : 24

        container.addSubview(titleStack)
        titleStack.anchor(top: container.safeTopAnchor,
                         leading: container.safeLeftAnchor,
                         bottom: nil,
                         trailing: container.safeRightAnchor,
                         padding: .init(top: 0, left: !UIDevice.isTablet() ? 20 : 80,
                                        bottom: 0, right: !UIDevice.isTablet() ? 20 : 80))

        container.addSubview(featuresLabel)
        featuresLabel.anchor(
            top: titleStack.bottomAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: UIDevice.isiPhoneSE() ? 20 : 30,
                left: 0,
                bottom: 0,
                right: 0
            )
        )

        featuresLabel.centerXInSuperview()

        container.addSubview(noteLabel)
        noteLabel.anchor(top: featuresLabel.bottomAnchor,
                         leading: titleStack.leadingAnchor,
                         bottom: nil,
                         trailing: titleStack.trailingAnchor,
                         padding: .init(top: UIDevice.isiPhoneSE() ? 20 : 30, left: 0,
                                        bottom: 0, right: 0))

        container.addSubview(continueButton)
        continueButton.anchor(top: noteLabel.bottomAnchor,
                              leading: container.safeLeftAnchor,
                              bottom: nil,
                              trailing: container.safeRightAnchor,
                              padding: .init(top: UIDevice.isiPhoneSE() ? 20 : 30,
                                             left: !UIDevice.isTablet() ? 50 : 150,
                                             bottom: 0,
                                             right: !UIDevice.isTablet() ? 50 : 150),
                              size: .init(width: 0, height: 50))

        container.addSubview(signInOptionalLabel)
        signInOptionalLabel.anchor(top: continueButton.bottomAnchor,
                               leading: container.safeLeftAnchor,
                               bottom: nil,
                               trailing: container.safeRightAnchor,
                               padding: .init(top: UIDevice.isiPhoneSE() ? 6 : 10,
                                              left: 30,
                                              bottom: 0,
                                              right: 30))

        signInOptionalLabel.bottomAnchor.constraint(
            lessThanOrEqualTo: container.bottomAnchor, constant: -30
        ).isActive = true
    }
}

extension SignInBenefitsViewController {
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
                                value: UIFont.Muli(.regular, size: UIDevice.isiPhoneSE() ? 16 : 18),
                                range: range)

        // Make note bold and orange color
        let makeBoldOrange = "note".localized()
        let boldFont = UIFont.Muli(.bold, size: UIDevice.isiPhoneSE() ? 16 : 18)
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
