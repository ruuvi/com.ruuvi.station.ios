import UIKit

class TagChartsScrollViewController: UIViewController {
    var output: TagChartsViewOutput!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
}

extension TagChartsScrollViewController: TagChartsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - IBActions
extension TagChartsScrollViewController {
    @IBAction func settingsButtonTouchUpInside(_ sender: UIButton) {
        
    }
    
    @IBAction func dashboardButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerDashboard()
    }
    
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        
    }
}
