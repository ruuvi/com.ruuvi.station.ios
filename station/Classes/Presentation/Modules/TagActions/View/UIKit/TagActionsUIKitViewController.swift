import UIKit
import BTKit

class TagActionsUIKitViewController: UIViewController {
    var output: TagActionsViewOutput!
    var viewModel: TagActionsViewModel! { didSet { bindViewModel() } }
    var syncProgress: BTServiceProgress? { didSet { updateUISyncProgress() } }
    
    @IBOutlet weak var statusLabel: UILabel!
    
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
    
    func showExportSheet(with path: URL) {
        
    }
    
    func localize() {
        updateUISyncProgress()
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
        updateUI()
        output.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        output.viewDidAppear()
    }
}

// MARK: - Update UI
extension TagActionsUIKitViewController {
    private func updateUI() {
        updateUISyncProgress()
    }
    
    private func updateUISyncProgress() {
        if isViewLoaded {
            if let syncProgress = syncProgress {
                switch syncProgress {
                case .connecting:
                    statusLabel.text = "TagActions.Status.Connecting".localized()
                case .serving:
                    statusLabel.text = "TagActions.Status.Serving".localized()
                case .disconnecting:
                    statusLabel.text = "TagActions.Status.Disconnecting".localized()
                case .success:
                    statusLabel.text = "TagActions.Status.Success".localized()
                case .failure:
                    statusLabel.text = "TagActions.Status.Error".localized()
                }
            } else {
                statusLabel.text = "TagActions.Status.Logs".localized()
            }
        }
    }
    
    private func bindViewModel() {
        if isViewLoaded {
            syncButton.bind(viewModel.isSyncEnabled) { (button, isSyncEnabled) in
                button.isHidden = !isSyncEnabled.bound
            }
        }
    }
}

