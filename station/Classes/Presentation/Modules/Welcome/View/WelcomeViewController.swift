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
        descriptionLabel.text = "Welcome.description.text".localized()
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
