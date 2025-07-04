import UIKit
import RuuviOntology

class MeasurementCardView: UIView {

    // MARK: - Layout Constants
    private struct Constants {
        static let cardHeight: CGFloat = 48
        static let cornerRadius: CGFloat = cardHeight / 2
        static let iconSize: CGFloat = 24
        static let stackSpacing: CGFloat = 8
        static let valueUnitSpacing: CGFloat = 4
        static let horizontalPadding: CGFloat = 8
        static let stackTopPadding: CGFloat = 6
        static let stackBottomPadding: CGFloat = 6
        static let valueFontSize: CGFloat = 24
        static let unitFontSize: CGFloat = 14
        static let titleFontSize: CGFloat = 14
    }

    var onTap: (() -> Void)?

    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private lazy var valueLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.Muli(.bold, size: 16)
        label.textColor = .white
        label.numberOfLines = 1
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private lazy var unitLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.Muli(.bold, size: 12)
        label.textAlignment = .left
        label.numberOfLines = 1
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return label
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .left
        label.font = UIFont.Muli(.regular, size: 12)
        label.textColor = UIColor.white.withAlphaComponent(0.8)
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        backgroundColor = UIColor.white.withAlphaComponent(0.1)
        layer.cornerRadius = Constants.cornerRadius

        let valueStackView = UIStackView(
            arrangedSubviews: [valueLabel, unitLabel]
        )
        valueStackView.distribution = .fill
        valueStackView.axis = .horizontal
        valueStackView.spacing = Constants.valueUnitSpacing
        valueStackView.alignment = .lastBaseline

        let labelStackView = UIStackView(
            arrangedSubviews: [valueStackView, titleLabel]
        )
        labelStackView.distribution = .fill
        labelStackView.axis = .vertical
        labelStackView.spacing = 0

        let contentStack = UIStackView(
            arrangedSubviews: [
                iconImageView, labelStackView
            ]
        )
        iconImageView.size(
            width: Constants.iconSize,
            height: Constants.iconSize
        )
        contentStack.axis = .horizontal
        contentStack.distribution = .fill
        contentStack.alignment = .center
        contentStack.spacing = Constants.stackSpacing

        addSubview(contentStack)
        contentStack.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottomAnchor,
            trailing: trailingAnchor,
            padding: UIEdgeInsets(
                top: Constants.stackTopPadding,
                left: Constants.horizontalPadding,
                bottom: Constants.stackBottomPadding,
                right: Constants.horizontalPadding
            )
        )
        contentStack.centerYInSuperview()

        // Set the card height
        self.constrainHeight(constant: Constants.cardHeight)

        let tapGesture = UITapGestureRecognizer(
            target: self,
            action: #selector(handleTap)
        )
        addGestureRecognizer(tapGesture)
    }

    @objc private func handleTap() {
        onTap?()
    }

    // MARK: - Configuration
    func configure(with indicator: RuuviTagCardSnapshotIndicatorData) {
        valueLabel.text = indicator.value
        unitLabel.text = indicator.unit
        titleLabel.text = indicator.type.displayName
        iconImageView.image = indicator.type.icon

        // Update tint color based on alert state
        let tintColor = indicator.isHighlighted ? UIColor.orange : UIColor.cyan
        iconImageView.tintColor = tintColor
    }
}
