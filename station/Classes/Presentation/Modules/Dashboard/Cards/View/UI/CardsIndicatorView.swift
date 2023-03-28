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
        let font = UIFont(name: "Montserrat-Bold", size: 18)
        label.font = font ?? UIFont.systemFont(ofSize: 16, weight: .bold)
        label.text = "Indicator"
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    convenience init(icon: UIImage?) {
        self.init()
        self.indicatorIconView.image = icon
        setUpUI()
    }

    fileprivate func setUpUI() {
        addSubview(indicatorIconView)
        indicatorIconView.anchor(top: nil,
                                 leading: leadingAnchor,
                                 bottom: nil,
                                 trailing: nil)
        indicatorIconView.heightAnchor.constraint(
            lessThanOrEqualToConstant: 50
        ).isActive = true
        indicatorIconView.widthAnchor.constraint(
            lessThanOrEqualToConstant: 50
        ).isActive = true
        indicatorIconView.centerYInSuperview()

        addSubview(indicatorValueLabel)
        indicatorValueLabel.anchor(top: nil,
                                   leading: indicatorIconView.trailingAnchor,
                                   bottom: nil,
                                   trailing: trailingAnchor,
                                   padding: .init(top: 0, left: 16, bottom: 0, right: 0))
        indicatorValueLabel.centerYInSuperview()
    }
}

extension CardsIndicatorView {
    func setValue(with value: String?) {
        indicatorValueLabel.text = value
    }

    func setIcon(with image: UIImage?) {
        indicatorIconView.image = image
    }
}
