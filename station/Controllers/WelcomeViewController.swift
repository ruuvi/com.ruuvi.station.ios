import UIKit

class WelcomeViewController: UIViewController {
    @IBOutlet weak var scanBtn: UIButton!
    
    override func viewDidLoad() {
        scanBtn.layer.borderColor = UIColor.white.cgColor
    }
    @IBAction func start(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: "hasShownWelcome")
        self.dismiss(animated: true, completion: nil)
    }
}
