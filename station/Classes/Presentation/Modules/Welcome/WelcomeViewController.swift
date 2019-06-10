import UIKit

class WelcomeViewController: UIViewController {
    
    @IBAction func scanButtonTouchUpInside(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
    }
    
}
