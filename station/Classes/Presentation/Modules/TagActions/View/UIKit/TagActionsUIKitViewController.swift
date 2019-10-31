import UIKit

class TagActionsUIKitViewController: UIViewController {
    var output: TagActionsViewOutput!
    var viewModel: TagActionsViewModel! { didSet { bindViewModel() } }
    
    @IBOutlet weak var environmentalLogsLabel: UIView!
    
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var syncButton: UIButton!
    @IBOutlet weak var exportButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!
    
}

// MARK: - TagActionsViewInput
extension TagActionsUIKitViewController: TagActionsViewInput {
    func showClearConfirmationDialog() {
        // handled by parent
    }
    
    func showSyncConfirmationDialog() {
        // handled by parent
    }
    
    func showExportDialog() {
        // handled by parent
    }
    
    func localize() {
        
    }
    
    func apply(theme: Theme) {
        
    }
}

// MARK: - IBActions
extension TagActionsUIKitViewController {
    @IBAction func exportButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToExport()
    }
    
    @IBAction func syncButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToSync()
    }
    
    @IBAction func clearButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToClear()
    }
}

// MARK: - View lifecycle
extension TagActionsUIKitViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        bindViewModel()
        output.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        output.viewDidAppear()
    }
}

extension TagActionsUIKitViewController {
    private func bindViewModel() {
        if isViewLoaded {
            syncButton.bind(viewModel.isSyncEnabled) { (button, isSyncEnabled) in
                button.isHidden = !isSyncEnabled.bound
            }
        }
    }
}

