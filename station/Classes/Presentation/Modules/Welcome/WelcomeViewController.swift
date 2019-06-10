import UIKit

class WelcomeViewController: UIViewController {
    
    @IBAction func scanButtonTouchUpInside(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
        
        let discoverStoryboard = UIStoryboard(name: "Discover", bundle: .main)
        if let discover = discoverStoryboard.instantiateInitialViewController() {
            navigationController?.pushViewController(discover, animated: true)
        }
    }
    
}
