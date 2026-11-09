import RuuviLocalization
import UIKit

protocol RuuviOnboardSignInCellDelegate: NSObjectProtocol {
    func didTapContinueButton(sender: RuuviOnboardSignInCell)
    func didProvideAnalyticsConsent(
        isConsentGiven: Bool,
        sender: RuuviOnboardSignInCell
    )
}

class RuuviOnboardSignInCell: UICollectionViewCell {
    weak var delegate: RuuviOnboardSignInCellDelegate?

    private lazy var beaverImageView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.Onboarding.onboardingBeaverSignIn.image,
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.montserrat(.extraBold, size: 36)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.mulish(.semiBoldItalic, size: 20)
        return label
    }()

    private lazy var tosCheckbox: RuuviOnboardCheckboxProvider = {
        let provider = RuuviOnboardCheckboxProvider()
        provider.delegate = self
        return provider
    }()

    private lazy var analyticsCheckbox: RuuviOnboardCheckboxProvider = {
        let provider = RuuviOnboardCheckboxProvider()
        provider.delegate = self
        return provider
    }()

    private lazy var continueButton: UIButton = {
        let button = UIButton(color: RuuviColor.tintColor.color, cornerRadius: 22)
        button.setTitle(
            RuuviLocalization.onboardingContinue,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.mulish(.bold, size: 16)
        button.addTarget(
            self,
            action: #selector(handleContinueTap),
            for: .touchUpInside
        )
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private extension RuuviOnboardSignInCell {

    // swiftlint:disable:next function_body_length
    func setUpUI() {
        // Scrolls only when the page is too short for its content (a short window), so the
        // checkboxes and Continue, the only way to finish onboarding, always stay reachable.
        let container = contentView.addScrollingPage().container

        let textStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel
        ])
        textStack.axis = .vertical
        textStack.distribution = .fillProportionally
        textStack.spacing = 12

        container.addSubview(textStack)
        textStack.anchor(
            top: container.safeTopAnchor,
            leading: container.safeLeadingAnchor,
            bottom: nil,
            trailing: container.safeTrailingAnchor,
            padding: .init(
                top: 44 + 12,
                left: 16,
                bottom: 0,
                right: 16
            )
        )

        let tosCheckboxVC = tosCheckbox.makeViewController(
            title: RuuviLocalization.onboardingStartTosTitle,
            titleMarkupString: RuuviLocalization.onboardingStartTosLinkMarkup,
            titleLink: RuuviLocalization.onboardingStartTosLink
        )
        tosCheckboxVC.view.backgroundColor = .clear
        container.addSubview(tosCheckboxVC.view)

        tosCheckboxVC.view.anchor(
            top: textStack.bottomAnchor,
            leading: container.safeLeadingAnchor,
            bottom: nil,
            trailing: container.safeTrailingAnchor,
            padding: .init(
                top: 16,
                left: 16,
                bottom: 0,
                right: 16
            )
        )

        let analyticsCheckboxVC = analyticsCheckbox.makeViewController(
            title: RuuviLocalization.onboardingStartAnonymousDataCollectionTitle,
            titleMarkupString: "",
            titleLink: ""
        )
        analyticsCheckboxVC.view.backgroundColor = .clear
        container.addSubview(analyticsCheckboxVC.view)

        analyticsCheckboxVC.view.anchor(
            top: tosCheckboxVC.view.bottomAnchor,
            leading: container.safeLeadingAnchor,
            bottom: nil,
            trailing: container.safeTrailingAnchor,
            padding: .init(
                top: 8,
                left: 16,
                bottom: 0,
                right: 16
            )
        )

        container.addSubview(continueButton)
        continueButton.anchor(
            top: analyticsCheckboxVC.view.bottomAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 20, left: 0, bottom: 0, right: 0),
            size: .init(width: 0, height: 44)
        )
        continueButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        continueButton.centerXInSuperview()
        setContinueButtonEnabled(false)

        // The checkbox texts are never squeezed in a short page; the page scrolls instead.
        tosCheckboxVC.view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
        analyticsCheckboxVC.view.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)

        let beaverContainerView = UIView(color: .clear)
        container.addSubview(beaverContainerView)
        beaverContainerView.anchor(
            top: continueButton.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor
        )
        // The beaver's space shrinks before the controls have to scroll, but not below the page's
        // bottom safe area + 12pt, so a scrolled page ends with Continue clear of the home indicator.
        // iPhones and full-screen iPads always have far more space than that: only short windows are
        // affected. (A length from contentView, outside the scroll view, so scrolling can't change it.)
        let bottomSafeAreaInset = contentView.safeBottomAnchor.anchorWithOffset(to: contentView.bottomAnchor)
        beaverContainerView.heightAnchor.constraint(
            greaterThanOrEqualTo: bottomSafeAreaInset,
            constant: 12
        ).isActive = true
        beaverContainerView.addSubview(beaverImageView)

        beaverImageView.anchor(
            top: nil,
            leading: beaverContainerView.safeLeadingAnchor,
            bottom: nil,
            trailing: beaverContainerView.safeTrailingAnchor
        )
        // Half the page height (as before), following the page when it is resized. Like before, the
        // beaver is centred in its space and cropped by it when that space is shorter.
        beaverImageView.heightAnchor.constraint(
            equalTo: contentView.heightAnchor,
            multiplier: 0.5
        ).isActive = true
        beaverImageView.centerYInSuperview()
    }

    private func setContinueButtonEnabled(
        _ enabled: Bool,
        animated: Bool = false
    ) {
        continueButton.isEnabled = enabled
        UIView.animate(withDuration: animated ? 0.5 : 0,
                       animations: {
            [weak self] in
            self?.continueButton.alpha = enabled ? 1 : 0.3
        })
    }
}

// MARK: - Private action
private extension RuuviOnboardSignInCell {
    @objc func handleContinueTap() {
        delegate?.didTapContinueButton(sender: self)
    }
}

// MARK: - Public
extension RuuviOnboardSignInCell {
    func configure(
        with viewModel: OnboardViewModel,
        tosAccepted: Bool) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        tosCheckbox.setChecked(tosAccepted)
        analyticsCheckbox.setChecked(false)
        setContinueButtonEnabled(tosAccepted)
    }
}

// MARK: - RuuviOnboardCheckboxViewDelegate
extension RuuviOnboardSignInCell: RuuviOnboardCheckboxViewDelegate {
    func didCheckCheckbox(
        isChecked: Bool,
        sender: RuuviOnboardCheckboxProvider
    ) {
        if sender == tosCheckbox {
            setContinueButtonEnabled(
                isChecked,
                animated: true
            )
        } else if sender == analyticsCheckbox {
            delegate?.didProvideAnalyticsConsent(
                isConsentGiven: isChecked,
                sender: self
            )
        }
    }
}
