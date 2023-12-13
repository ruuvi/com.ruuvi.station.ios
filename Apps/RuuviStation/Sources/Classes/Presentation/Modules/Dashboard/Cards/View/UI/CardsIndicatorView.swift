import UIKit

class CardsIndicatorView: UIView {
    private lazy var indicatorIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var indicatorValueLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.bold, size: 18)
        return label
    }()

    private lazy var indicatorUnitLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 14)
        label.sizeToFit()
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(icon: UIImage?) {
        self.init()
        indicatorIconView.image = icon
        setUpUI()
    }

    fileprivate func setUpUI() {
        addSubview(indicatorIconView)
        indicatorIconView.anchor(
            top: nil,
            leading: leadingAnchor,
            bottom: nil,
            trailing: nil
        )
        indicatorIconView.heightAnchor.constraint(
            lessThanOrEqualToConstant: 50
        ).isActive = true
        indicatorIconView.widthAnchor.constraint(
            lessThanOrEqualToConstant: 50
        ).isActive = true
        indicatorIconView.centerYInSuperview()

        addSubview(indicatorValueLabel)
        indicatorValueLabel.anchor(
            top: nil,
            leading: indicatorIconView.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 16, bottom: 0, right: 0)
        )
        indicatorValueLabel.centerYInSuperview()

        addSubview(indicatorUnitLabel)
        indicatorUnitLabel.anchor(
            top: nil,
            leading: indicatorValueLabel.trailingAnchor,
            bottom: indicatorValueLabel.bottomAnchor,
            trailing: nil,
            padding: .init(
                top: 0,
                left: 4,
                bottom: 0,
                right: 0
            )
        )
        indicatorUnitLabel
            .topAnchor
            .constraint(
                lessThanOrEqualTo: indicatorValueLabel.topAnchor,
                constant: 3
            ).isActive = true

        indicatorUnitLabel.trailingAnchor
            .constraint(greaterThanOrEqualTo: trailingAnchor)
            .isActive = true
    }
}

extension CardsIndicatorView {
    func setValue(with value: String?, unit: String? = nil) {
        indicatorValueLabel.text = value
        indicatorUnitLabel.text = unit

        indicatorValueLabel.sizeToFit()
        indicatorUnitLabel.sizeToFit()
        layoutIfNeeded()
    }

    func setIcon(with image: UIImage?) {
        indicatorIconView.image = image
    }

    func clearValues() {
        indicatorValueLabel.text = nil
        indicatorUnitLabel.text = nil
    }
}
