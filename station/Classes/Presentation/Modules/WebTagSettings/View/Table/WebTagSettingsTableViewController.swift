import UIKit

private enum WebTagSettingsSection: Int {
    case name = 0
    case moreInfo = 1
}

class WebTagSettingsTableViewController: UITableViewController {
    var output: WebTagSettingsViewOutput!
    
    @IBOutlet weak var tagNameTextField: UITextField!
    @IBOutlet weak var backgroundImageView: UIImageView!
    @IBOutlet weak var tagNameCell: UITableViewCell!
    @IBOutlet weak var locationCell: UITableViewCell!
    @IBOutlet weak var locationValueLabel: UILabel!
    @IBOutlet weak var clearLocationButton: UIButton!
    @IBOutlet weak var clearLocationButtonWidth: NSLayoutConstraint!
    @IBOutlet weak var backgroundImageLabel: UILabel!
    @IBOutlet weak var tagNameTitleLabel: UILabel!
    @IBOutlet weak var removeThisWebTagButton: UIButton!
    @IBOutlet weak var locationTitleLabel: UILabel!
    
    
    
    var viewModel = WebTagSettingsViewModel() { didSet { bindViewModel() } }
}

// MARK: - WebTagSettingsViewInput
extension WebTagSettingsTableViewController: WebTagSettingsViewInput {
    func localize() {
        navigationItem.title = "WebTagSettings.navigationItem.title".localized()
        backgroundImageLabel.text = "WebTagSettings.Label.BackgroundImage.text".localized()
        tagNameTitleLabel.text = "WebTagSettings.Label.TagName.text".localized()
        locationTitleLabel.text = "WebTagSettings.Label.Location.text".localized()
        removeThisWebTagButton.setTitle("WebTagSettings.Button.Remove.title".localized(), for: .normal)
    }
    
    func apply(theme: Theme) {
        
    }
    
    func showTagRemovalConfirmationDialog() {
        let controller = UIAlertController(title: "WebTagSettings.confirmTagRemovalDialog.title".localized(), message: "WebTagSettings.confirmTagRemovalDialog.message".localized(), preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(), style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmTagRemoval()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }
    
    func showClearLocationConfirmationDialog() {
        let controller = UIAlertController(title: "WebTagSettings.confirmClearLocationDialog.title".localized(), message: "WebTagSettings.confirmClearLocationDialog.message".localized(), preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Confirm".localized(), style: .destructive, handler: { [weak self] _ in
            self?.output.viewDidConfirmToClearLocation()
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
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
    
    @IBAction func selectBackgroundButtonTouchUpInside(_ sender: UIButton) {
        output.viewDidAskToSelectBackground(sourceView: sender)
    }
    
    @IBAction func tagNameTextFieldEditingDidEnd(_ sender: Any) {
        if let name = tagNameTextField.text {
            output.viewDidChangeTag(name: name)
        }
    }
    
    @IBAction func removeThisWebTagButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToRemoveWebTag()
    }
    
    @IBAction func clearLocationButtonTouchUpInside(_ sender: Any) {
        output.viewDidAskToClearLocation()
    }
}

// MARK: - View lifecycle
extension WebTagSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        bindViewModel()
    }
}

// MARK: - UITableViewDelegate
extension WebTagSettingsTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        if let cell = tableView.cellForRow(at: indexPath) {
            switch cell {
            case tagNameCell:
                tagNameTextField.becomeFirstResponder()
            case locationCell:
                output.viewDidAskToSelectLocation()
            default:
                break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case WebTagSettingsSection.name.rawValue:
            return "WebTagSettings.SectionHeader.Name.title".localized()
        case WebTagSettingsSection.moreInfo.rawValue:
            return "WebTagSettings.SectionHeader.MoreInfo.title".localized()
        default:
            return nil
        }
    }
}
// MARK: - UITextFieldDelegate
extension WebTagSettingsTableViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return false
    }
}

// MARK: - Private
extension WebTagSettingsTableViewController {
    private func bindViewModel() {
        backgroundImageView.bind(viewModel.background) { $0.image = $1 }
        tagNameTextField.bind(viewModel.name) { $0.text = $1 }
        let clearButton = clearLocationButton
        let clearWidth = clearLocationButtonWidth
        locationValueLabel.bind(viewModel.location, block: { [weak clearButton, weak clearWidth] label, location in
            label.text = location?.cityCommaCountry ?? "WebTagSettings.Location.Current".localized()
            clearButton?.isHidden = location == nil
            clearWidth?.constant = location == nil ? 0 : 36
        })
    }
}
