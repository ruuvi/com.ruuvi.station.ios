import UIKit

public final class ActivityRuuviLogoViewController: UIViewController {
    var statusBarStyle = UIStatusBarStyle.default
    var statusBarHidden = false

    private var logoImageView = UIImageView()
    var spinnerView = ActivitySpinnerView()
    var messageLabel = UILabel()
    
    public init() {
        super.init(nibName: nil, bundle: nil)
        setupView()
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        logoImageView.tintColor = UIColor.white
        messageLabel.textColor = .white
    }

    public override var preferredStatusBarStyle: UIStatusBarStyle {
        guard let topVC = UIApplication.shared.topViewController() else { return statusBarStyle }
        if !topVC.isKind(of: ActivityRuuviLogoViewController.self) {
            statusBarStyle = topVC.preferredStatusBarStyle
        }
        return statusBarStyle
    }

    public override var prefersStatusBarHidden: Bool {
        guard let topVC = UIApplication.shared.topViewController() else { return statusBarHidden }
        if !topVC.isKind(of: ActivityRuuviLogoViewController.self) {
            statusBarHidden = topVC.prefersStatusBarHidden
        }
        return statusBarHidden
    }
    
    private func setupView() {
        view.backgroundColor = UIColor(white: 0, alpha: 0.8)
        
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(logoImageView)
        NSLayoutConstraint.activate([
            logoImageView.widthAnchor.constraint(equalToConstant: 64),
            logoImageView.heightAnchor.constraint(equalToConstant: 64),
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
        ])
        
        logoImageView.image = UIImage.named("ruuvi_logo_for_activity_presenter", for: Self.self)
        
        spinnerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(spinnerView)
        NSLayoutConstraint.activate([
            spinnerView.widthAnchor.constraint(equalToConstant: 80),
            spinnerView.heightAnchor.constraint(equalToConstant: 80),
            spinnerView.centerXAnchor.constraint(equalTo: logoImageView.centerXAnchor),
            spinnerView.centerYAnchor.constraint(equalTo: logoImageView.centerYAnchor),
        ])
        
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(messageLabel)
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: messageLabel.trailingAnchor, constant: 16),
            messageLabel.topAnchor.constraint(equalTo: spinnerView.bottomAnchor, constant: 16),
        ])
    }
}
