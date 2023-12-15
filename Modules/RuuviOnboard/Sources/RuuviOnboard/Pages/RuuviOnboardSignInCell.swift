import RuuviLocalization
import UIKit

protocol RuuviOnboardSignInCellDelegate: NSObjectProtocol {
    func didTapContinueButton(sender: RuuviOnboardSignInCell)
}

class RuuviOnboardSignInCell: UICollectionViewCell {
    weak var delegate: RuuviOnboardSignInCellDelegate?

    private lazy var beaverImageView: UIImageView = {
        let iv = UIImageView(
            image: UIImage.named(
                RuuviAssets.beaver_sign_in,
                for: Self.self
            ),
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
        label.font = UIFont.Montserrat(.extraBold, size: 36)
        return label
    }()

    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.semiBoldItalic, size: 20)
        return label
    }()

    private lazy var continueButton: UIButton = {
        let button = UIButton(color: RuuviColor.tintColor.color, cornerRadius: 22)
        button.setTitle(
            RuuviLocalization.onboardingContinue,
            for: .normal
        )
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 16)
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
    func setUpUI() {
        let container = UIView(color: .clear)
        contentView.addSubview(container)
        container.fillSuperview()

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

        container.addSubview(continueButton)
        continueButton.anchor(
            top: textStack.bottomAnchor,
            leading: nil,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 20, left: 0, bottom: 0, right: 0),
            size: .init(width: 0, height: 44)
        )
        continueButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140).isActive = true
        continueButton.centerXInSuperview()

        let beaverContainerView = UIView(color: .clear)
        container.addSubview(beaverContainerView)
        beaverContainerView.anchor(
            top: continueButton.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor
        )
        beaverContainerView.addSubview(beaverImageView)

        beaverImageView.anchor(
            top: nil,
            leading: beaverContainerView.safeLeadingAnchor,
            bottom: nil,
            trailing: beaverContainerView.safeTrailingAnchor,
            size: .init(width: 0, height: bounds.height / 2)
        )
        beaverImageView.centerYInSuperview()
    }
}

private extension RuuviOnboardSignInCell {
    @objc func handleContinueTap() {
        delegate?.didTapContinueButton(sender: self)
    }
}

extension RuuviOnboardSignInCell {
    func configure(with viewModel: OnboardViewModel) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
    }
}
