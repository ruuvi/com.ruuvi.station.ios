import UIKit
import RuuviBundleUtils

final class RuuviOnboardImageTitleViewController: UIViewController {
    init(imageName: String, titleKey: String, isWelcomScreen: Bool = false) {
        self.isWelcomeScreen = isWelcomScreen
        self.imageName = imageName
        self.titleKey = titleKey
        self.imageView = Self.makeImageView()
        self.titleLabel = Self.makeTitleLabel()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        styleViews()
        localizeViews()
        layoutViews()
    }

    private func setupViews() {
        view.addLayoutGuide(guide)
        view.addSubview(imageView)
        view.addSubview(titleLabel)
    }

    private func styleViews() {
        imageView.image = UIImage.named(imageName, for: Self.self)
    }

    private func layoutViews() {
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            guide.topAnchor.constraint(equalTo: imageView.topAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 36),
            imageView.heightAnchor.constraint(equalToConstant: isWelcomeScreen ? 148 : 88),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            guide.bottomAnchor.constraint(equalTo: titleLabel.topAnchor),
            guide.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: 40),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func localizeViews() {
        titleLabel.text = titleKey.localized(for: Self.self)
    }

    private let guide = UILayoutGuide()
    private let imageView: UIImageView
    private let titleLabel: UILabel
    private let imageName: String
    private let titleKey: String
    private let isWelcomeScreen: Bool
}

// MARK: - Factory
extension RuuviOnboardImageTitleViewController {
    private static func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }

    private static func makeTitleLabel() -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        return label
    }
}
