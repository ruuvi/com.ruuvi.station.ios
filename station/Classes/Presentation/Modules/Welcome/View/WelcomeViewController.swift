import UIKit

class WelcomeViewController: UIViewController {
    var output: WelcomeViewOutput!
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension WelcomeViewController: WelcomeViewInput {
    func localize() {
        
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
