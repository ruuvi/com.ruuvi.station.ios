import UIKit
import RealmSwift

class DashboardScrollViewController: UIViewController {
    var output: DashboardViewOutput!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var ruuviTags: Results<RuuviTagRealm>! { didSet { updateUIRuuviTags() }  }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
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
    @IBAction func settingsButtonTouchUpInside(_ sender: UIButton) {
        
    }
    
    @IBAction func menuButtonTouchUpInside(_ sender: Any) {
        output.viewDidTriggerMenu()
    }
}

// MARK: - View lifecycle
extension DashboardScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        output.viewDidLoad()
    }
}

// MARK: - Update UI
extension DashboardScrollViewController {
    private func updateUI() {
        updateUIRuuviTags()
    }
    
    private func updateUIRuuviTags() {
        if isViewLoaded {
            
        }
    }
}
