import RuuviLocalization
import UIKit

final class MenuNewsletterView: UIView {
    var onSubscribe: (() -> Void)?

    private let cardView: UIView = {
        let view = UIView()
        view.backgroundColor = RuuviColor.secondary.color
        view.layer.cornerRadius = 12
        return view
    }()

    private let imageView: UIImageView = {
        let imageView = UIImageView(image: RuuviAsset.beaverMail.image)
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .ruuviHeadlineSmall()
        label.textAlignment = .center
        label.textColor = RuuviColor.textColor.color
        label.numberOfLines = 0
        return label
    }()

    private let descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .ruuviBodySmall()
        label.textAlignment = .center
        label.textColor = RuuviColor.textColor.color.withAlphaComponent(0.8)
        label.numberOfLines = 0
        return label
    }()

    private lazy var subscribeButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = RuuviColor.tintColor.color
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .ruuviButtonSmall()
        button.addTarget(self, action: #selector(subscribeButtonTapped), for: .touchUpInside)
        return button
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
        localize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        subscribeButton.layer.cornerRadius = subscribeButton.bounds.height / 2
    }

    private func setUp() {
        backgroundColor = .clear

        addSubview(cardView)
        [imageView, titleLabel, descriptionLabel, subscribeButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            cardView.addSubview($0)
        }
        cardView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Keep the card near the bottom of the available footer space. On
            // taller screens this leaves the same breathing room below the menu
            // rows as the design, while still allowing the footer to scroll on
            // smaller screens.
            cardView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 80),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),

            imageView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: cardView.topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 118),
            imageView.heightAnchor.constraint(equalToConstant: 132),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 68),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            descriptionLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            descriptionLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            subscribeButton.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 12),
            subscribeButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            subscribeButton.widthAnchor.constraint(equalTo: cardView.widthAnchor, multiplier: 0.68),
            subscribeButton.widthAnchor.constraint(lessThanOrEqualToConstant: 232),
            subscribeButton.heightAnchor.constraint(equalToConstant: 44),
            subscribeButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
        ])
    }

    private func localize() {
        titleLabel.text = RuuviLocalization.newsletterCardTitle
        descriptionLabel.text = RuuviLocalization.newsletterCardDescription
        subscribeButton.setTitle(RuuviLocalization.newsletterSubscribe, for: .normal)
    }

    @objc private func subscribeButtonTapped() {
        onSubscribe?()
    }
}
