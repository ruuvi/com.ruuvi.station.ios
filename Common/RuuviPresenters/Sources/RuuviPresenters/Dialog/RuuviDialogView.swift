import RuuviLocalization
import UIKit

public struct RuuviDialogConfiguration {
    public let title: String
    public let message: String?
    public let image: UIImage?
    public let primaryActionTitle: String
    public let secondaryActionTitle: String?

    public init(
        title: String,
        message: String? = nil,
        image: UIImage? = nil,
        primaryActionTitle: String,
        secondaryActionTitle: String? = nil
    ) {
        self.title = title
        self.message = message
        self.image = image
        self.primaryActionTitle = primaryActionTitle
        self.secondaryActionTitle = secondaryActionTitle
    }
}

/// A content-sized dialog card. Its content scrolls when the available height is limited.
public final class RuuviDialogView: UIView {
    public var onPrimaryAction: (() -> Void)?
    public var onSecondaryAction: (() -> Void)?

    private enum Layout {
        static let horizontalPadding: CGFloat = 32
        static let topPadding: CGFloat = 44
        static let bottomPadding: CGFloat = 24
        static let imageHeight: CGFloat = 144
        static let buttonHeight: CGFloat = 48
    }

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let titleLabel = UILabel()
    private let imageView = UIImageView()
    private let messageLabel = UILabel()
    private let errorLabel = UILabel()
    private let primaryButton = UIButton(type: .system)
    private let secondaryButton = UIButton(type: .system)
    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let imageContainer = UIView()
    private let primaryButtonContainer = UIView()

    public init(configuration: RuuviDialogConfiguration) {
        super.init(frame: .zero)
        setUp()
        configure(configuration)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func configure(_ configuration: RuuviDialogConfiguration) {
        titleLabel.text = configuration.title
        imageView.image = configuration.image
        imageContainer.isHidden = configuration.image == nil
        messageLabel.text = configuration.message
        messageLabel.isHidden = configuration.message == nil
        primaryButton.setTitle(configuration.primaryActionTitle, for: .normal)
        secondaryButton.setTitle(configuration.secondaryActionTitle, for: .normal)
        secondaryButton.isHidden = configuration.secondaryActionTitle == nil
        setLoading(false)
        showError(nil)
        scrollView.setContentOffset(.zero, animated: false)
        setNeedsLayout()
    }

    public func setLoading(_ loading: Bool) {
        primaryButton.isEnabled = !loading
        secondaryButton.isEnabled = !loading
        primaryButton.titleLabel?.alpha = loading ? 0 : 1
        if loading {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    public func showError(_ message: String?) {
        errorLabel.text = message
        errorLabel.isHidden = message == nil
        setNeedsLayout()
        if let message {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }

    func preferredHeight(for width: CGFloat) -> CGFloat {
        let contentSize = stackView.systemLayoutSizeFitting(
            CGSize(width: max(0, width - 2 * Layout.horizontalPadding), height: 0),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        return ceil(contentSize.height) + Layout.topPadding + Layout.bottomPadding
    }

    func focusTitle() {
        UIAccessibility.post(notification: .screenChanged, argument: titleLabel)
    }

    private func setUp() {
        backgroundColor = RuuviColor.dialogBackground.color
        layer.cornerRadius = 16
        clipsToBounds = true
        accessibilityViewIsModal = true
        setUpContent()
        setUpLayout()
    }

    private func setUpContent() {
        titleLabel.font = .ruuviHeadlineMedium()
        titleLabel.accessibilityTraits.insert(.header)
        messageLabel.font = .ruuviBody()
        errorLabel.font = .ruuviBodySmall()
        [titleLabel, messageLabel, errorLabel].forEach {
            $0.textAlignment = .center
            $0.textColor = .white
            $0.numberOfLines = 0
            $0.setContentCompressionResistancePriority(.required, for: .vertical)
        }
        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = false

        primaryButton.setTitleColor(.white, for: .normal)
        primaryButton.addTarget(self, action: #selector(primaryAction), for: .touchUpInside)
        secondaryButton.setTitleColor(RuuviColor.dialogAccent.color, for: .normal)
        secondaryButton.addTarget(self, action: #selector(secondaryAction), for: .touchUpInside)
        [primaryButton, secondaryButton].forEach {
            var configuration = UIButton.Configuration.plain()
            configuration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 12, bottom: 10, trailing: 12)
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.ruuviButtonLarge()
                return attributes
            }
            $0.configuration = configuration
            $0.titleLabel?.numberOfLines = 0
            $0.titleLabel?.textAlignment = .center
        }
        primaryButton.configuration?.background.backgroundColor = RuuviColor.dialogAccent.color
        primaryButton.configuration?.cornerStyle = .capsule
        primaryButton.tintColor = .white
        secondaryButton.tintColor = RuuviColor.dialogAccent.color
        activityIndicator.color = .white
        activityIndicator.hidesWhenStopped = true
    }

    private func setUpLayout() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = 28
        [titleLabel, imageContainer, messageLabel, errorLabel, primaryButtonContainer, secondaryButton]
            .forEach { stackView.addArrangedSubview($0) }
        stackView.setCustomSpacing(32, after: imageContainer)
        stackView.setCustomSpacing(16, after: primaryButtonContainer)

        addSubview(scrollView)
        scrollView.addSubview(stackView)
        imageContainer.addSubview(imageView)
        primaryButtonContainer.addSubview(primaryButton)
        primaryButton.addSubview(activityIndicator)
        [scrollView, stackView, imageView, primaryButton, activityIndicator].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
        }
        activateLayoutConstraints()
    }

    private func activateLayoutConstraints() {
        let imageHeight = imageView.heightAnchor.constraint(equalToConstant: Layout.imageHeight)
        imageHeight.priority = .defaultHigh
        let secondaryHeight = secondaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        secondaryHeight.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor,
                                           constant: Layout.topPadding),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor,
                                              constant: -Layout.bottomPadding),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor,
                                               constant: Layout.horizontalPadding),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor,
                                                constant: -Layout.horizontalPadding),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor,
                                             constant: -2 * Layout.horizontalPadding),
            imageView.centerXAnchor.constraint(equalTo: imageContainer.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: imageContainer.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: imageContainer.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: imageContainer.widthAnchor),
            imageHeight,
            primaryButton.topAnchor.constraint(equalTo: primaryButtonContainer.topAnchor),
            primaryButton.bottomAnchor.constraint(equalTo: primaryButtonContainer.bottomAnchor),
            primaryButton.centerXAnchor.constraint(equalTo: primaryButtonContainer.centerXAnchor),
            primaryButton.widthAnchor.constraint(equalTo: primaryButtonContainer.widthAnchor, multiplier: 0.64),
            primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.buttonHeight),
            secondaryHeight,
            activityIndicator.centerXAnchor.constraint(equalTo: primaryButton.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: primaryButton.centerYAnchor),
        ])
    }

    @objc private func primaryAction() { onPrimaryAction?() }
    @objc private func secondaryAction() { onSecondaryAction?() }
}
