import RuuviLocalization
import UIKit

class RuuviOnboardGatewayFeaturesCell: UICollectionViewCell {
    private lazy var appImageView: UIImageView = {
        let iv = UIImageView(
            image: nil,
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

    private lazy var gateWayImageView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.Onboarding.gateway.image,
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var gatewayRequireLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.text = RuuviLocalization.onboardingGatewayRequired
        label.font = UIFont.mulish(.semiBoldItalic, size: 16)
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

private extension RuuviOnboardGatewayFeaturesCell {
    // swiftlint:disable:next function_body_length
    func setUpUI() {
        let container = UIView(color: .clear)
        contentView.addSubview(container)
        container.fillSuperview()

        let textStack = UIStackView(arrangedSubviews: [
            subtitleLabel, titleLabel
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

        let appImageViewContainer = UIView(color: .clear)
        container.addSubview(appImageViewContainer)
        appImageViewContainer.anchor(
            top: textStack.bottomAnchor,
            leading: container.safeLeadingAnchor,
            bottom: nil,
            trailing: container.safeTrailingAnchor
        )

        appImageViewContainer.addSubview(appImageView)
        if UIDevice.isTablet() {
            appImageView.fillSuperview(padding: .init(top: 60, left: 60, bottom: 60, right: 60))
        } else {
            appImageView.fillSuperview(padding: .init(top: 30, left: 30, bottom: 30, right: 30))
        }

        let footerView = UIView(color: RuuviColor.tintColor.color)
        container.addSubview(footerView)
        footerView.anchor(
            top: appImageViewContainer.bottomAnchor,
            leading: container.leadingAnchor,
            bottom: container.bottomAnchor,
            trailing: container.trailingAnchor
        )

        let stackView = UIStackView(arrangedSubviews: [
            gateWayImageView, gatewayRequireLabel
        ])
        stackView.distribution = .fillProportionally
        stackView.spacing = 8
        stackView.axis = .horizontal
        gateWayImageView.size(width: 70, height: 60)

        footerView.addSubview(stackView)
        stackView.anchor(
            top: footerView.topAnchor,
            leading: nil,
            bottom: footerView.safeBottomAnchor,
            trailing: nil,
            padding: .init(
                top: 12,
                left: 0,
                bottom: bottomSafeAreaHeight > 0 ? 0 : 12,
                right: 0
            )
        )

        stackView.leadingAnchor.constraint(
            lessThanOrEqualTo: footerView.leadingAnchor, constant: 20
        ).isActive = true
        stackView.trailingAnchor.constraint(
            lessThanOrEqualTo: footerView.trailingAnchor, constant: -20
        ).isActive = true

        stackView.centerXInSuperview()
    }
}

extension RuuviOnboardGatewayFeaturesCell {
    func configure(with viewModel: OnboardViewModel) {
        switch viewModel.pageType {
        case .share:
            subtitleLabel.font = UIFont.montserrat(.extraBold, size: 36)
            titleLabel.font = UIFont.mulish(.semiBoldItalic, size: 20)
        default:
            subtitleLabel.font = UIFont.mulish(.semiBoldItalic, size: 20)
            titleLabel.font = UIFont.montserrat(.extraBold, size: 36)
        }

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        guard let image = viewModel.image
        else {
            return
        }
        appImageView.image = image
    }
}
