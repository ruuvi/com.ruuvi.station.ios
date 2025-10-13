import Foundation
import RuuviLocalization
import UIKit

class SignInBenefitsViewController: UIViewController, SignInBenefitsViewInput {
    // Configuration
    var output: SignInBenefitsViewOutput?

    // UI Componenets starts
    private lazy var closeButton: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: RuuviAsset.dismissModalIcon.image,
            style: .plain,
            target: self,
            action: #selector(handleCloseButtonTap)
        )
        button.tintColor = .white
        return button
    }()

    private lazy var bgLayer: UIImageView = {
        let iv = UIImageView(image: RuuviAsset.commonBgLayer.image)
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
        label.text = RuuviLocalization.whyShouldSignIn
        label.font = UIFont.mulish(.extraBold, size: UIDevice.isiPhoneSE() ? 24 : 30)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = RuuviLocalization.sensorsOwnershipAndSettingsStoredInCloud
        label.font = UIFont.mulish(.semiBoldItalic, size: UIDevice.isiPhoneSE() ? 16 : 20)
        return label
    }()

    private lazy var featuresLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.text = prepareFeatures()
        label.font = UIFont.ruuviBody()
        return label
    }()

    private lazy var noteLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.ruuviBody()
        label.attributedText = prepareNote()
        return label
    }()

    private lazy var continueButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(
            RuuviLocalization.signInContinue,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.ruuviButtonMedium()
        button.addTarget(
            self,
            action: #selector(handleContinueTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var signInOptionalLabel: UILabel = {
        let label = UILabel()
        label.text = RuuviLocalization.signingInIsOptional
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.ruuviBody()
        return label
    }()
}

// MARK: - VIEW LIFE CYCLE

extension SignInBenefitsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.makeTransparent()
    }
}

extension SignInBenefitsViewController {
    @objc private func handleCloseButtonTap() {
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

    private func setUpNavBarView() {
        navigationItem.leftBarButtonItem = closeButton
    }

    private func setUpBase() {
        view.backgroundColor = RuuviColor.primary.color

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
        titleStack.anchor(
            top: container.safeTopAnchor,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: 0,
                left: !UIDevice.isTablet() ? 20 : 80,
                bottom: 0,
                right: !UIDevice.isTablet() ? 20 : 80
            )
        )

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
        noteLabel.anchor(
            top: featuresLabel.bottomAnchor,
            leading: titleStack.leadingAnchor,
            bottom: nil,
            trailing: titleStack.trailingAnchor,
            padding: .init(
                top: UIDevice.isiPhoneSE() ? 20 : 30,
                left: 0,
                bottom: 0,
                right: 0
            )
        )

        container.addSubview(continueButton)
        continueButton.anchor(
            top: noteLabel.bottomAnchor,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: UIDevice.isiPhoneSE() ? 20 : 30,
                left: !UIDevice.isTablet() ? 50 : 150,
                bottom: 0,
                right: !UIDevice.isTablet() ? 50 : 150
            ),
            size: .init(width: 0, height: 50)
        )

        container.addSubview(signInOptionalLabel)
        signInOptionalLabel.anchor(
            top: continueButton.bottomAnchor,
            leading: container.safeLeftAnchor,
            bottom: nil,
            trailing: container.safeRightAnchor,
            padding: .init(
                top: UIDevice.isiPhoneSE() ? 6 : 10,
                left: 30,
                bottom: 0,
                right: 30
            )
        )

        signInOptionalLabel.bottomAnchor.constraint(
            lessThanOrEqualTo: container.bottomAnchor, constant: -30
        ).isActive = true
    }
}

extension SignInBenefitsViewController {
    private func prepareFeatures() -> String {
        [
            RuuviLocalization.cloudStoredOwnerships,
            RuuviLocalization.cloudStoredNames,
            RuuviLocalization.cloudStoredAlerts,
            RuuviLocalization.cloudStoredBackgrounds,
            RuuviLocalization.cloudStoredCalibration,
            RuuviLocalization.cloudStoredSharing,
        ].joined(separator: "\n")
    }

    private func prepareNote() -> NSMutableAttributedString {
        let text = RuuviLocalization.note + " " + RuuviLocalization.claimWarning

        let attrString = NSMutableAttributedString(string: text)
        let range = NSString(string: attrString.string).range(of: attrString.string)
        attrString.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.ruuviBody(),
            range: range
        )

        // Make note bold and orange color
        let makeBoldOrange = RuuviLocalization.note
        let boldFont = UIFont.ruuviBody()
        let boldRange = NSString(string: attrString.string).range(of: makeBoldOrange)
        attrString.addAttribute(
            NSAttributedString.Key.font,
            value: boldFont,
            range: boldRange
        )
        attrString.addAttribute(
            .foregroundColor,
            value: RuuviColor.orangeColor.color,
            range: boldRange
        )

        // Make rest of the text white
        let regularRange = NSString(string: attrString.string)
            .range(of: RuuviLocalization.claimWarning)
        attrString.addAttribute(
            .foregroundColor,
            value: UIColor.white,
            range: regularRange
        )

        return attrString
    }
}
