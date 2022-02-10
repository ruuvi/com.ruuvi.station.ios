import UIKit

protocol RuuviOnboardStartViewControllerDelegate: AnyObject {
    func ruuviOnboardStart(_ viewController: RuuviOnboardStartViewController, didFinish sender: Any?)
}

final class RuuviOnboardStartViewController: UIViewController {
    weak var delegate: RuuviOnboardStartViewControllerDelegate?

    init() {
        self.imageView = Self.makeImageView()
        self.label = Self.makeLabel()
        self.button = Self.makeButton()
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
        view.addSubview(label)
        view.addSubview(button)

        button.addTarget(self, action: #selector(Self.buttonTouchUpInside(_:)), for: .touchUpInside)
    }

    @objc
    private func buttonTouchUpInside(_ sender: Any) {
        delegate?.ruuviOnboardStart(self, didFinish: nil)
    }

    private func styleViews() {
        imageView.image = UIImage.named("get_started", for: Self.self)
    }

    private func localizeViews() {
        label.text = "RuuviOnboard.Start.title".localized(for: Self.self)
        button.setTitle("RuuviOnboard.Start.button".localized(for: Self.self), for: .normal)
    }

    private func layoutViews() {
        label.translatesAutoresizingMaskIntoConstraints = false
        button.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            view.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: 20),
            button.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            button.heightAnchor.constraint(equalToConstant: 50),
            guide.topAnchor.constraint(equalTo: imageView.bottomAnchor),
            guide.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            guide.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            guide.bottomAnchor.constraint(equalTo: button.topAnchor),
            label.centerXAnchor.constraint(equalTo: guide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: guide.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            view.trailingAnchor.constraint(equalTo: label.trailingAnchor, constant: 32)
        ])
    }

    private let imageView: UIImageView
    private let label: UILabel
    private let button: UIButton
    private let guide = UILayoutGuide()
}

// MARK: - Factory
extension RuuviOnboardStartViewController {
    private static func makeImageView() -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        return imageView
    }

    private static func makeLabel() -> UILabel {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }

    private static func makeButton() -> UIButton {
        let button = UIButton()
        button.layer.cornerRadius = 25
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 15)
        return button
    }
}
