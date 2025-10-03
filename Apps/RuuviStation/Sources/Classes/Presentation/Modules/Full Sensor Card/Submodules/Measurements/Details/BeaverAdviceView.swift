import RuuviLocalization
import UIKit

class BeaverAdviceView: UIView {
    // MARK: - Constants

    private enum Constants {
        static let cornerRadius: CGFloat = 16
        static let borderWidth: CGFloat = 1
        static let containerPadding: CGFloat = 10
        static let beaverSize: CGFloat = 85
        static let beaverTextSpacing: CGFloat = 16
        static let beaverMinVerticalSpacing: CGFloat = 10
        static let textVerticalPadding: CGFloat = 8
    }

    // MARK: - UI Components

    private let containerView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Constants.cornerRadius
        view.layer.borderWidth = Constants.borderWidth
        view.layer.borderColor = RuuviColor.tintColor.color.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let beaverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.image = RuuviAsset.beaverAdvice.image
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    private let adviceLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .left
        label.font = UIFont.ruuviSubheadline()
        label.textColor = RuuviColor.dashboardIndicator.color
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Properties

    var adviceText: String? {
        get { adviceLabel.text }
        set { adviceLabel.text = newValue }
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    // MARK: - Setup

    // swiftlint:disable:next function_body_length
    private func setupViews() {
        backgroundColor = .clear

        addSubview(containerView)
        containerView.addSubview(beaverImageView)
        containerView.addSubview(adviceLabel)

        NSLayoutConstraint.activate([
            // Container fills the view
            containerView.topAnchor.constraint(
                equalTo: topAnchor
            ),
            containerView.leadingAnchor.constraint(
                equalTo: leadingAnchor
            ),
            containerView.trailingAnchor.constraint(
                equalTo: trailingAnchor
            ),
            containerView.bottomAnchor.constraint(
                equalTo: bottomAnchor
            ),

            // Beaver image - fixed size, vertically centered
            beaverImageView.leadingAnchor.constraint(
                equalTo: containerView.leadingAnchor,
                constant: Constants.containerPadding
            ),
            beaverImageView.centerYAnchor.constraint(
                equalTo: containerView.centerYAnchor
            ),
            beaverImageView.topAnchor.constraint(
                greaterThanOrEqualTo: containerView.topAnchor,
                constant: Constants.beaverMinVerticalSpacing
            ),
            beaverImageView.bottomAnchor.constraint(
                lessThanOrEqualTo: containerView.bottomAnchor,
                constant: -Constants.beaverMinVerticalSpacing
            ),
            beaverImageView.widthAnchor.constraint(
                equalToConstant: Constants.beaverSize
            ),
            beaverImageView.heightAnchor.constraint(
                equalToConstant: Constants.beaverSize
            ),

            // Advice label - flexible width, grows with content
            adviceLabel.leadingAnchor.constraint(
                equalTo: beaverImageView.trailingAnchor,
                constant: Constants.beaverTextSpacing
            ),
            adviceLabel.trailingAnchor.constraint(
                equalTo: containerView.trailingAnchor,
                constant: -Constants.containerPadding
            ),
            adviceLabel.topAnchor.constraint(
                equalTo: containerView.topAnchor,
                constant: Constants.containerPadding +
                    Constants.textVerticalPadding
            ),
            adviceLabel.bottomAnchor.constraint(
                equalTo: containerView.bottomAnchor,
                constant: -(Constants.containerPadding +
                    Constants.textVerticalPadding)
            ),
        ])
    }

    // MARK: - Configuration

    func configure(with advice: String) {
        adviceText = advice
    }
}
