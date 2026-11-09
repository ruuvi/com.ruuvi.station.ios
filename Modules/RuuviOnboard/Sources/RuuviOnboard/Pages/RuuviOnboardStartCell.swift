import RuuviLocalization
import UIKit

class RuuviOnboardStartCell: UICollectionViewCell {
    private lazy var beaverImageView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.Onboarding.onboardingBeaverStart.image,
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

    private lazy var sub_subtitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.mulish(.semiBoldItalic, size: 20)
        return label
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

private extension RuuviOnboardStartCell {
    func setUpUI() {
        // Scrolls only when the page is too short for the text (a short window).
        let container = contentView.addScrollingPage().container

        let textStack = UIStackView(arrangedSubviews: [
            titleLabel, subtitleLabel, sub_subtitleLabel
        ])
        textStack.axis = .vertical
        textStack.distribution = .fill
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

        let beaverContainerView = UIView(color: .clear)
        container.addSubview(beaverContainerView)
        beaverContainerView.anchor(
            top: textStack.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor
        )
        // The beaver's space shrinks to nothing before the text has to scroll.
        beaverContainerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
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
}

extension RuuviOnboardStartCell {
    func configure(with viewModel: OnboardViewModel) {
        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        sub_subtitleLabel.text = viewModel.sub_subtitle
    }
}
