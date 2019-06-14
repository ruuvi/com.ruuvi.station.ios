import UIKit

class DashboardScrollViewController: UIViewController {
    var output: DashboardViewOutput!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
}

// MARK: - DashboardViewInput
extension DashboardScrollViewController: DashboardViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}


// MARK: - IBActions
extension DashboardScrollViewController {
    @IBAction func tagSettingsClick(_ sender: UIButton) {
        
    }
}
