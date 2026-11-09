import RuuviLocalization
import UIKit

class RuuviOnboardGatewayFeaturesCell: UICollectionViewCell {
    private var footerRowSwitch: RuuviVerticalBarConstraintSwitch?
    /// Top, leading, bottom and trailing space around the app image; each constant is the padding.
    private var appImagePaddingConstraints: [NSLayoutConstraint] = []
    private var appliedAppImagePadding: CGFloat?
    /// Scrolls the text and the image only when the page is too short for them.
    private weak var pageScrollView: UIScrollView?

    override func layoutSubviews() {
        footerRowSwitch?.update(for: traitCollection)
        updateAppImagePadding()
        super.layoutSubviews()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Size classes are only known in a window: lay out again there, so the padding is right
        // even if the cell was first laid out outside one.
        if window != nil {
            setNeedsLayout()
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // The cell shows several pages: start each one at its top.
        pageScrollView?.contentOffset = .zero
    }

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
        // The teal footer stays at the bottom of the page. The text and the image above it scroll
        // only when the page is too short for them (a short window).
        let footerView = UIView(color: RuuviColor.tintColor.color)
        contentView.addSubview(footerView)
        footerView.anchor(
            top: nil,
            leading: contentView.leadingAnchor,
            bottom: contentView.bottomAnchor,
            trailing: contentView.trailingAnchor
        )

        let page = contentView.addScrollingPage(bottom: footerView.topAnchor)
        pageScrollView = page.scrollView
        let container = page.container

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
            bottom: container.bottomAnchor,
            trailing: container.safeTrailingAnchor
        )

        appImageViewContainer.addSubview(appImageView)
        appImageView.translatesAutoresizingMaskIntoConstraints = false
        appImagePaddingConstraints = [
            appImageView.topAnchor.constraint(equalTo: appImageViewContainer.topAnchor),
            appImageView.leadingAnchor.constraint(equalTo: appImageViewContainer.leadingAnchor),
            appImageViewContainer.bottomAnchor.constraint(equalTo: appImageView.bottomAnchor),
            appImageViewContainer.trailingAnchor.constraint(equalTo: appImageView.trailingAnchor),
        ]
        NSLayoutConstraint.activate(appImagePaddingConstraints)
        updateAppImagePadding()
        // The image is the part that gives way: it shrinks (down to nothing) before the text is
        // compressed or the page scrolls, and it takes any extra height instead of the text.
        appImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        appImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        appImageView.setContentHuggingPriority(.defaultLow - 1, for: .vertical)

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
            bottom: nil,
            trailing: nil,
            padding: .init(top: 12, left: 0, bottom: 0, right: 0)
        )

        // The row ends on the footer's own safe area where it has a bottom inset (home indicator),
        // otherwise 12pt above the footer's edge: the larger of the two, updated with the window.
        let safeArea = footerView.safeAreaLayoutGuide
        let rowOnSafeArea = stackView.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor)
        rowOnSafeArea.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: footerView.bottomAnchor, constant: -12),
            rowOnSafeArea,
        ])

        // iPhone Duo: the teal footer runs edge to edge, but its row is centred in the safe area so
        // it stays clear of the vertical bar. Elsewhere the original constraints are used.
        footerRowSwitch = RuuviVerticalBarConstraintSwitch(
            standard: [
                stackView.leadingAnchor.constraint(lessThanOrEqualTo: footerView.leadingAnchor, constant: 20),
                stackView.trailingAnchor.constraint(lessThanOrEqualTo: footerView.trailingAnchor, constant: -20),
                stackView.centerXAnchor.constraint(equalTo: footerView.centerXAnchor),
            ],
            // Same sizing as the original constraints produce (the row spans the width minus 20pt on
            // each side), measured from the safe area instead of the footer edges.
            verticalBar: [
                stackView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
                stackView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            ]
        )
    }

    /// 60pt around the image in the iPad layout (regular width and height), 30pt otherwise (iPhone,
    /// narrow or short windows). Re-applied on every layout pass, so it follows size-class changes;
    /// does nothing while the padding is unchanged.
    func updateAppImagePadding() {
        let padding: CGFloat = traitCollection.ruuviLayoutClass.isRegular ? 60 : 30
        guard padding != appliedAppImagePadding else { return }
        appliedAppImagePadding = padding
        appImagePaddingConstraints.forEach { $0.constant = padding }
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
