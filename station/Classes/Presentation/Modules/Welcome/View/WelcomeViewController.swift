import UIKit

class WelcomeViewController: UIViewController {
    var output: WelcomeViewOutput!

    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var welcomeImageView: UIImageView!

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

}

extension WelcomeViewController: WelcomeViewInput {
    func localize() {
        configureDescriptionLabel()
        scanButton.setTitle("Welcome.scan.title".localized(), for: .normal)
    }

    func apply(theme: Theme) {

    }
}

// MARK: - IBActions
extension WelcomeViewController {
    @IBAction func scanButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerScan()
    }
}

// MARK: - View lifecycle
extension WelcomeViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        configureViews()
    }
}

// MARK: - View configuration
extension WelcomeViewController {
    private func configureViews() {
        configureDescriptionLabel()
    }

    private func configureDescriptionLabel() {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.alignment = .center
        let attrString = NSMutableAttributedString(string: "Welcome.description.text".localized())
        attrString.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: attrString.length))
        descriptionLabel.attributedText = attrString
    }
}
