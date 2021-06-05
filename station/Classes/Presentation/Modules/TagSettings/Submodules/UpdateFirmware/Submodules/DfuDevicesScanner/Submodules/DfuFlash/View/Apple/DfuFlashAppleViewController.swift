import Foundation
import UIKit

class DfuFlashAppleViewController: UIViewController, DfuFlashViewInput {
    var output: DfuFlashViewOutput!
    var viewModel = DfuFlashViewModel()
    var dfuFlashState: DfuFlashState = .packageSelection {
        didSet {
            DispatchQueue.main.async {
                self.syncUIs()
            }
        }
    }
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var selectionView: UIView!
    @IBOutlet weak var selectionLabel: UILabel!
    @IBOutlet weak var documentPickerButton: UIButton!

    @IBOutlet weak var flashView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var logTableView: UITableView!

    @IBOutlet weak var successView: UIView!
    @IBOutlet weak var successLabel: UILabel!
    @IBOutlet weak var finishButton: UIButton!

    private var flashLogs: [DfuLog] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        logTableView.tableFooterView = UIView()
        logTableView.rowHeight = UITableView.automaticDimension
        setupLocalization()
        bindViewModel()
        output.viewDidLoad()
    }

    func localize() {
        title = "DfuFlash.Title.text".localized()
        selectionLabel.text = "DfuFlash.FirmwareSelectionGuide.text".localized()
        successLabel.text = "DfuFlash.FinishGuide.text".localized()
    }

    func showCancelFlashDialog() {
        let message = "DfuFlash.CancelAlert.text".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        alertVC.addAction(UIAlertAction(title: "OK".localized(),
                                        style: .default,
                                        handler: { [weak self] _ in
                                            self?.output.viewDidConfirmCancelFlash()
                                        }))
        present(alertVC, animated: true)
    }
}

// MARK: - IBOutlet
extension DfuFlashAppleViewController {
    @IBAction func documentPickerButtonAction(_ sender: UIButton) {
        output.viewDidOpenDocumentPicker(sourceView: sender)
    }

    @IBAction func cancelButtonAction(_ sender: Any) {
        output.viewDidCancelFlash()
    }

    @IBAction func startButtonAction(_ sender: Any) {
        output.viewDidStartFlash()
    }

    @IBAction func finishButtonAction(_ sender: Any) {
        output.viewDidFinishFlash()
    }
}

// MARK: - UITableViewDataSource
extension DfuFlashAppleViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return flashLogs.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: DfuLogTableViewCell.self, for: indexPath)
        let flashLog = flashLogs[indexPath.row]
        cell.messageLabel.text = flashLog.message
        cell.messageLabel.backgroundColor = indexPath.row % 2 == 0
            ? .lightGray.withAlphaComponent(0.5)
            : .clear
        return cell
    }
}

// MARK: - UITableViewDelegate
extension DfuFlashAppleViewController: UITableViewDelegate {
}

// MARK: - UI
extension DfuFlashAppleViewController {
    private func syncUIs() {
        guard isViewLoaded else {
            return
        }
        switch dfuFlashState {
        case .completed:
            selectionView.isHidden = true
            flashView.isHidden = true
            successView.isHidden = false
        case .uploading,
             .readyForUpload:
            selectionView.isHidden = true
            flashView.isHidden = false
            successView.isHidden = true
            startButton.isEnabled = dfuFlashState == .readyForUpload
            startButton.backgroundColor = dfuFlashState == .readyForUpload
                ? .normalButton
                : .disableButton
        default:
            selectionView.isHidden = false
            flashView.isHidden = true
            successView.isHidden = true
        }
        if let index = DfuFlashState.allCases.firstIndex(of: dfuFlashState) {
            switch dfuFlashState {
            case .packageSelection:
                stepLabel.text = "DfuFlash.Step.text".localized()
                    + " \(index + 1)/\(DfuFlashState.allCases.count): "
                    + "DfuFlash.Steps.PackageSelection.text".localized()
            case .readyForUpload:
                stepLabel.text = "DfuFlash.Step.text".localized()
                    + " \(index + 1)/\(DfuFlashState.allCases.count): "
                    + "DfuFlash.Steps.ReadyForUpload.text".localized()
            case .uploading:
                stepLabel.text = "DfuFlash.Step.text".localized()
                    + " \(index + 1)/\(DfuFlashState.allCases.count): "
                    + "DfuFlash.Steps.Uploading.text".localized()
            case .completed:
                stepLabel.text = "DfuFlash.Step.text".localized()
                    + " \(index + 1)/\(DfuFlashState.allCases.count): "
                    + "DfuFlash.Steps.Completed.text".localized()
            }
        }
    }

    private func bindViewModel() {
        progressView.bind(viewModel.flashProgress) { v, progress in
            v.setProgress(progress ?? 0, animated: progress != nil)
        }

        logTableView.bind(viewModel.flashLogs) {[weak self] tableView, logs in
            self?.flashLogs = logs ?? []
            tableView.reloadData()
            if let logs = logs {
                tableView.scrollToRow(at: IndexPath(row: logs.count - 1, section: 0),
                                      at: .bottom,
                                      animated: true)
            }
        }
    }
}
