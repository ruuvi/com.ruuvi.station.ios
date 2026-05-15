import UIKit
import RuuviLocalization

final class AlertBellButton: UIButton {

    var bellLayer: CALayer {
        return bellImageView.layer
    }

    var bellImage: UIImage? {
        get { bellImageView.image }
        set { bellImageView.image = newValue }
    }

    var bellTintColor: UIColor {
        get { bellImageView.tintColor }
        set { bellImageView.tintColor = newValue }
    }

    var bellAlpha: CGFloat {
        get { bellImageView.alpha }
        set { bellImageView.alpha = newValue }
    }

    private let bellImageView = UIImageView()
    private let badgeView = AlertBadgeView()
    private let iconSize: CGSize
    private let iconCenterOffset: CGPoint

    private enum Constants {
        static let iconSize = CGSize(
            width: 30,
            height: 30
        )
        static let iconCenterOffset = CGPoint.zero
        static let badgeTopOffset: CGFloat = 4
        static let badgeCenterXFromIconTrailing: CGFloat = -4
    }

    init(
        iconSize: CGSize = Constants.iconSize,
        iconCenterOffset: CGPoint = Constants.iconCenterOffset
    ) {
        self.iconSize = iconSize
        self.iconCenterOffset = iconCenterOffset
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configureBell(
        image: UIImage?,
        tintColor: UIColor,
        alpha: CGFloat
    ) {
        bellImage = image?.withRenderingMode(.alwaysTemplate)
        bellTintColor = tintColor
        bellAlpha = alpha
    }

    func configureBadge(
        count: Int,
        isTriggered: Bool,
        normalTextColor: UIColor
    ) {
        badgeView.configure(
            count: count,
            isTriggered: isTriggered,
            normalTextColor: normalTextColor
        )
    }

    func hideBadge() {
        badgeView.hide()
    }

    func removeBellAnimations() {
        bellLayer.removeAllAnimations()
    }

    private func setupUI() {
        backgroundColor = .clear

        bellImageView.image = RuuviAsset.CardsMenu.iconAlerts.image
        bellImageView.tintColor = .white
        bellImageView.contentMode = .scaleAspectFit
        bellImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(bellImageView)

        badgeView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(badgeView)

        NSLayoutConstraint.activate([
            bellImageView.centerXAnchor.constraint(
                equalTo: centerXAnchor,
                constant: iconCenterOffset.x
            ),
            bellImageView.centerYAnchor.constraint(
                equalTo: centerYAnchor,
                constant: iconCenterOffset.y
            ),
            bellImageView.widthAnchor.constraint(equalToConstant: iconSize.width),
            bellImageView.heightAnchor.constraint(equalToConstant: iconSize.height),

            badgeView.topAnchor.constraint(
                equalTo: bellImageView.topAnchor,
                constant: Constants.badgeTopOffset
            ),
            badgeView.centerXAnchor.constraint(
                equalTo: bellImageView.trailingAnchor,
                constant: Constants.badgeCenterXFromIconTrailing
            ),
        ])
    }
}

final class AlertBadgeView: UIView {

    private let label = UILabel()
    private var heightConstraint: NSLayoutConstraint!
    private var minimumWidthConstraint: NSLayoutConstraint!
    private var labelLeadingConstraint: NSLayoutConstraint!
    private var labelTrailingConstraint: NSLayoutConstraint!

    private enum Constants {
        static let bubbleHeight: CGFloat = 15
        static let bubbleHorizontalPadding: CGFloat = 4
        static let textHorizontalPadding: CGFloat = 0
        static let fontSize: CGFloat = 10
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
    }

    func configure(
        count: Int,
        isTriggered: Bool,
        normalTextColor: UIColor
    ) {
        guard count > 0 else {
            hide()
            return
        }

        label.text = count > 99 ? "99+" : "\(count)"
        label.textColor = isTriggered ? .white : normalTextColor
        backgroundColor = isTriggered ? RuuviColor.orangeColor.color : .clear
        minimumWidthConstraint.isActive = isTriggered
        labelLeadingConstraint.constant = isTriggered ?
            Constants.bubbleHorizontalPadding :
            Constants.textHorizontalPadding
        labelTrailingConstraint.constant = isTriggered ?
            -Constants.bubbleHorizontalPadding :
            -Constants.textHorizontalPadding
        isHidden = false
    }

    func hide() {
        isHidden = true
        label.text = nil
        backgroundColor = .clear
        minimumWidthConstraint.isActive = false
    }

    private func setupUI() {
        isHidden = true
        isUserInteractionEnabled = false
        clipsToBounds = true

        label.font = UIFont.mulish(.extraBold, size: Constants.fontSize)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.75
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)

        addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        heightConstraint = heightAnchor.constraint(equalToConstant: Constants.bubbleHeight)
        minimumWidthConstraint = widthAnchor.constraint(greaterThanOrEqualTo: heightAnchor)
        labelLeadingConstraint = label.leadingAnchor.constraint(
            equalTo: leadingAnchor,
            constant: Constants.textHorizontalPadding
        )
        labelTrailingConstraint = label.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -Constants.textHorizontalPadding
        )

        NSLayoutConstraint.activate([
            heightConstraint,
            label.topAnchor.constraint(equalTo: topAnchor),
            labelLeadingConstraint,
            label.bottomAnchor.constraint(equalTo: bottomAnchor),
            labelTrailingConstraint,
        ])
    }
}
