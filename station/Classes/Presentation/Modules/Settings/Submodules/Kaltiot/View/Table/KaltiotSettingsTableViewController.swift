import UIKit

class KaltiotSettingsTableViewController: UITableViewController {
    @IBOutlet weak var apiKeyTextField: UITextField!

    var output: KaltiotSettingsViewOutput!
    var viewModel: KaltiotSettingsViewModel = KaltiotSettingsViewModel() {
        didSet {
            updateUI()
        }
    }
// MARK: - Actions
    @IBAction func apiKeyDidEndEditing(_ sender: UITextField) {
        output.viewDidEnterApiKey(sender.text)
    }
}

// MARK: - KaltiotSettingsViewInput
extension KaltiotSettingsTableViewController: KaltiotSettingsViewInput {
    func localize() {
        title = "KaltiotSettings.title".localized()
        apiKeyTextField.placeholder = "KaltiotSettings.ApiKeyTextField.placeholder".localized()
        tableView.reloadData()
    }
}

// MARK: - View lifecycle
extension KaltiotSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        updateUI()
    }
}

// MARK: - UITableViewDelegate
extension KaltiotSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Update UI
extension KaltiotSettingsTableViewController {
    private func updateUI() {
        bindViewModel()
    }

    private func bindViewModel() {
        apiKeyTextField?.bind(viewModel.apiKey) { (textField, text) in
            textField.text = text
            textField.becomeFirstResponder()
        }
    }
}
