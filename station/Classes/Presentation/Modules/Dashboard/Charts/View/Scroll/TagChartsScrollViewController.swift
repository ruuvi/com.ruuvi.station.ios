import UIKit

class TagChartsScrollViewController: UIViewController {
    var output: TagChartsViewOutput!
    
    @IBOutlet weak var settingsButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    
    var viewModels = [TagChartsViewModel]()
}

// MARK: - TagChartsViewInput
extension TagChartsScrollViewController: TagChartsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
    
    func scroll(to index: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let sSelf = self else { return }
            let x: CGFloat = sSelf.scrollView.frame.size.width * CGFloat(index)
            sSelf.scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
        }
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

// MARK: - View lifecycle
extension TagChartsScrollViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
    }
}
