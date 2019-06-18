import UIKit

class WelcomeViewController: UIViewController {
    var output: WelcomeViewOutput!
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
