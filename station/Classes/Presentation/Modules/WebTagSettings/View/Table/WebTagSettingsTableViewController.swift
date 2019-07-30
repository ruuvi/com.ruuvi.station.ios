import UIKit

class WebTagSettingsTableViewController: UITableViewController {
    var output: WebTagSettingsViewOutput!
    
    @IBOutlet weak var tagNameTextField: UITextField!
    @IBOutlet weak var backgroundImageView: UIImageView!
    
    var viewModel = WebTagSettingsViewModel() { didSet { bindViewModel() } }
}

// MARK: - WebTagSettingsViewInput
extension WebTagSettingsTableViewController: WebTagSettingsViewInput {
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - IBActions
extension WebTagSettingsTableViewController {
    @IBAction func dismissBarButtonItemAction(_ sender: Any) {
        output.viewDidAskToDismiss()
    }
    
    @IBAction func randomizeBackgroundButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRandomizeBackground()
    }
    
    @IBAction func selectBackgroundButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToSelectBackground()
    }
}

// MARK: - View lifecycle
extension WebTagSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        bindViewModel()
    }
}

// MARK: - Private
extension WebTagSettingsTableViewController {
    private func bindViewModel() {
        backgroundImageView.bind(viewModel.background) { $0.image = $1 }
        tagNameTextField.bind(viewModel.name) { $0.text = $1 }
    }
}
