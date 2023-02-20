import UIKit

class RuuviOnboardCoreFeaturesCell: UICollectionViewCell {

    private lazy var appImageView: UIImageView = {
        let iv = UIImageView(image: nil,
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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension RuuviOnboardCoreFeaturesCell {

    fileprivate func setUpUI() {

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
        textStack.anchor(top: container.safeTopAnchor,
                         leading: container.safeLeadingAnchor,
                         bottom: nil,
                         trailing: container.safeTrailingAnchor,
                         padding: .init(top: 44+12, left: 16,
                                        bottom: 0, right: 16))

        container.addSubview(appImageView)
        appImageView.anchor(top: textStack.bottomAnchor,
                            leading: container.safeLeadingAnchor,
                            bottom: nil,
                            trailing: container.safeTrailingAnchor,
                            padding: .init(top: 30, left: 0, bottom: 0, right: 0))
        appImageView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor).isActive = true
    }
}

extension RuuviOnboardCoreFeaturesCell {
    func configure(with viewModel: OnboardViewModel) {

        switch viewModel.pageType {
        case .sensors:
            subtitleLabel.font = UIFont.Montserrat(.extraBold, size: 36)
            titleLabel.font = UIFont.Muli(.semiBoldItalic, size: 20)
        default:
            subtitleLabel.font = UIFont.Muli(.semiBoldItalic, size: 20)
            titleLabel.font = UIFont.Montserrat(.extraBold, size: 36)
        }

        titleLabel.text = viewModel.title
        subtitleLabel.text = viewModel.subtitle
        guard let image = viewModel.image else {
            return
        }
        appImageView.image = UIImage.named(image, for: Self.self)
    }
}
