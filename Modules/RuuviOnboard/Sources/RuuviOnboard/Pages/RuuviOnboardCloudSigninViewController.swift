import UIKit
import RuuviUser

protocol RuuviOnboardCloudSigninViewControllerDelegate: AnyObject {
    func ruuviOnboardShowSignIn(_ viewController: RuuviOnboardCloudSigninViewController, didShowSignIn sender: Any?)
}

final class RuuviOnboardCloudSigninViewController: UIViewController {
    weak var delegate: RuuviOnboardCloudSigninViewControllerDelegate?
    var ruuviUser: RuuviUser?

    init() {
        self.imageView = Self.makeImageView()
        self.titleLabel = Self.makeLabel()
        self.subtitleLabel = Self.makeLabel()
        self.detailsButton = Self.makeButton()
        self.signInButton = Self.makeButton()
        self.buttonsContainer = Self.makeButtonsContainer()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        styleViews()
        localizeViews()
        layoutViews()
        updateUI()
        startObservingUserSignedInNotification()
    }

    private func startObservingUserSignedInNotification() {
        NotificationCenter
            .default
            .addObserver(forName: .RuuviUserDidAuthorized,
                         object: nil,
                         queue: .main,
                         using: { [weak self] _ in
                self?.updateUI()
            })
    }

    private func updateUI() {
        guard let ruuviUser = ruuviUser else {
            return
        }
        if ruuviUser.isAuthorized {
            signInButton.removeFromSuperview()
            subtitleLabel.text = "RuuviOnboard.Cloud.subtitle.signed".localized(for: Self.self)
        }
    }

    private func setupViews() {
        view.addLayoutGuide(guide)
        view.addSubview(imageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(buttonsContainer)
        buttonsContainer.addArrangedSubview(signInButton)
        buttonsContainer.addArrangedSubview(detailsButton)

        signInButton.addTarget(self, action: #selector(Self.handleSignInButtonTap(_:)), for: .touchUpInside)
        detailsButton.addTarget(self, action: #selector(Self.handleDetailsButtonTap(_:)), for: .touchUpInside)
    }

    @objc
    private func handleSignInButtonTap(_ sender: Any) {
        delegate?.ruuviOnboardShowSignIn(self, didShowSignIn: nil)
    }

    @objc
    private func handleDetailsButtonTap(_ sender: Any) {
        let title = "RuuviOnboard.Cloud.Benefits.title".localized(for: Self.self)
        let message = "RuuviOnboard.Cloud.Benefits.message"
            .localized(for: Self.self)
            .replacingOccurrences(of: "\\n\\n",
                                  with: "\n\n")
        let closeActionTitle = "RuuviOnboard.Cloud.Close.title".localized(for: Self.self).uppercased()
        let closeAction = UIAlertAction(title: closeActionTitle,
                                         style: .cancel,
                                         handler: nil)
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.setMessageAlignment(.left)
        alert.addAction(closeAction)
        present(alert, animated: true)
    }

    private func styleViews() {
        imageView.image = UIImage.named("ruuvi-cloud", for: Self.self)
    }

    private func localizeViews() {
        titleLabel.text = "RuuviOnboard.Cloud.title".localized(for: Self.self)
        subtitleLabel.text = "RuuviOnboard.Cloud.subtitle".localized(for: Self.self)
        signInButton.setTitle("RuuviOnboard.Cloud.SignIn.title".localized(for: Self.self).uppercased(), for: .normal)
        detailsButton.setTitle("RuuviOnboard.Cloud.Details.title".localized(for: Self.self).uppercased(), for: .normal)
    }

    private func layoutViews() {
        NSLayoutConstraint.activate([
            guide.topAnchor.constraint(equalTo: imageView.topAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 36),
            imageView.heightAnchor.constraint(equalToConstant: isiPhoneSE() ? 120 : 148),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            guide.bottomAnchor.constraint(equalTo: titleLabel.topAnchor),
            guide.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: isiPhoneSE() ? 20 : 40),
            view.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: isiPhoneSE() ? 20 : 40),
            guide.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),

            view.bottomAnchor.constraint(equalTo: buttonsContainer.bottomAnchor, constant: 20),
            buttonsContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            buttonsContainer.heightAnchor.constraint(equalToConstant: 56),
            detailsButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 140)
        ])
    }

    private let imageView: UIImageView
    private let titleLabel: UILabel
    private let subtitleLabel: UILabel
    private let signInButton: UIButton
    private let detailsButton: UIButton
    private let buttonsContainer: UIStackView
    private let guide = UILayoutGuide()
}

// MARK: - Factory
extension RuuviOnboardCloudSigninViewController {
    private static func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }

    private static func makeLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private static func makeButtonsContainer() -> UIStackView {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    private static func makeButton() -> UIButton {
        let button = UIButton()
        button.layer.cornerRadius = 28
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
}