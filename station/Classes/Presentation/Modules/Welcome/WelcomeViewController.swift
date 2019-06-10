import UIKit

class WelcomeViewController: UIViewController {
    
    @IBAction func scanButtonTouchUpInside(_ sender: Any) {
        rememberWelcomeWasShown()
        openDiscover()
    }
    
    private func rememberWelcomeWasShown() {
        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
    }
    
    private func openDiscover() {
        let discoverStoryboard = UIStoryboard(name: "Discover", bundle: .main)
        if let discover = discoverStoryboard.instantiateInitialViewController() {
            navigationController?.pushViewController(discover, animated: true)
        }
    }
}
