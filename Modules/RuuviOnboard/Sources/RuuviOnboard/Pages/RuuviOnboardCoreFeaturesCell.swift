import UIKit

class RuuviOnboardCoreFeaturesCell: UICollectionViewCell {
    /// Scrolls the page only when it is too short for its content.
    private weak var pageScrollView: UIScrollView?

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

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUpUI()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        // The cell shows several pages: start each one at its top.
        pageScrollView?.contentOffset = .zero
    }
}

private extension RuuviOnboardCoreFeaturesCell {
    func setUpUI() {
        // Scrolls only when the page is too short for the text (a short window).
        let page = contentView.addScrollingPage()
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

        container.addSubview(appImageView)
        appImageView.anchor(
            top: textStack.bottomAnchor,
            leading: container.safeLeadingAnchor,
            bottom: nil,
            trailing: container.safeTrailingAnchor,
            padding: .init(top: 30, left: 0, bottom: 0, right: 0)
        )
        appImageView.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor).isActive = true
        // The screenshot is the part that gives way when the page is short: it shrinks (down to
        // nothing) before the text is compressed, and only then does the page scroll.
        appImageView.heightAnchor.constraint(greaterThanOrEqualToConstant: 0).isActive = true
        appImageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }
}

extension RuuviOnboardCoreFeaturesCell {
    func configure(with viewModel: OnboardViewModel) {
        switch viewModel.pageType {
        case .sensors:
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
