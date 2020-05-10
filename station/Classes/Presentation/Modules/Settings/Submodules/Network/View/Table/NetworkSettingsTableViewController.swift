import UIKit

enum NetworkSettingsSection: Int, CaseIterable {
    case common
    case whereOS
    case kaltiot
//    case aws

    init(indexPath: IndexPath) {
        guard let section = NetworkSettingsSection(rawValue: indexPath.section) else {
            fatalError()
        }
        self = section
    }
}

class NetworkSettingsTableViewController: UITableViewController {
    var output: NetworkSettingsViewOutput!
    var viewModel: NetworkSettingsViewModel = NetworkSettingsViewModel() {
        didSet {
            updateUI()
        }
    }
    private var networkFeatureEnabled: Bool {
        return viewModel.networkFeatureEnabled.value ?? false
    }
}

// MARK: - KaltiotSettingsViewInput
extension NetworkSettingsTableViewController: NetworkSettingsViewInput {
    func localize() {
        title = "NetworkSettings.title".localized()
        tableView.reloadData()
    }
}

// MARK: - View lifecycle
extension NetworkSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        output.viewDidLoad()
        setupLocalization()
        updateUI()
    }
}

// MARK: - UITableViewDelegate
extension NetworkSettingsTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return networkFeatureEnabled ? NetworkSettingsSection.allCases.count : 1
    }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = NetworkSettingsSection(rawValue: section)
        switch section {
        case .common, .whereOS:
            return 1
        case .kaltiot:
            return viewModel.kaltiotNetworkEnabled.value == true ? 2 : 1
        default:
            return 0
        }
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch NetworkSettingsSection(indexPath: indexPath) {
        case .common:
            let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
            cell.settingsSwitch.isOn = networkFeatureEnabled
            cell.settingsSwitch.addTarget(self,
                                          action: #selector(didChangeNetworkFeatureEnabled(_:)),
                                          for: .valueChanged)
            cell.settingsTitleLabel.text = "NetworkSettings.NetworkFeature".localized()
            return cell
        case .whereOS:
            let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
            cell.settingsSwitch.isOn = viewModel.whereOSNetworkEnabled.value ?? false
            cell.settingsSwitch.addTarget(self,
                                          action: #selector(didChangeWhereOSNetworkEnabled(_:)),
                                          for: .valueChanged)
            cell.settingsTitleLabel.text = "NetworkSettings.WhereOS".localized()
            return cell
        case .kaltiot:
            switch indexPath.row {
            case 0:
                let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
                cell.settingsSwitch.isOn = viewModel.kaltiotNetworkEnabled.value ?? false
                cell.settingsSwitch.addTarget(self,
                                              action: #selector(didChangeKaltiotNetworkEnabled(_:)),
                                              for: .valueChanged)
                cell.settingsTitleLabel.text = "NetworkSettings.Kaltiot".localized()
                return cell
            case 1:
                let cell = tableView.dequeueReusableCell(with: KaltiotApiKeyTableViewCell.self, for: indexPath)
                cell.apiKeyTextField.text = viewModel.kaltiotApiKey.value
                cell.apiKeyTextField.placeholder = "KaltiotSettings.ApiKeyTextField.placeholder".localized()
                cell.apiKeyTextField.addTarget(self,
                                               action: #selector(didEndEditingApiKey(_:)),
                                               for: .editingDidEndOnExit)
                return cell
            default:
                fatalError()
            }
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch NetworkSettingsSection(rawValue: section) {
        case .whereOS?:
            return "NetworkSettings.WhereOS".localized()
        case .kaltiot:
            return "NetworkSettings.Kaltiot".localized()
        default:
            return nil
        }
    }
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
         if let section = NetworkSettingsSection(rawValue: section),
            section == .kaltiot,
            viewModel.kaltiotNetworkEnabled.value == true {
            return "KaltiotSettings.FooterTextView.text".localized()
        } else {
            return nil
        }
    }
}

// MARK: - Private
extension NetworkSettingsTableViewController {
    private func updateUI() {
        tableView.reloadData()
    }
    @objc func didChangeNetworkFeatureEnabled(_ sender: UISwitch) {
        output.viewDidTriggerNetworkFeatureSwitch(sender.isOn)
        updateUI()
    }
    @objc func didChangeWhereOSNetworkEnabled(_ sender: UISwitch) {
        output.viewDidTriggerWhereOsSwitch(sender.isOn)
        updateUI()
    }
    @objc func didChangeKaltiotNetworkEnabled(_ sender: UISwitch) {
        output.viewDidTriggerKaltiotSwitch(sender.isOn)
        tableView.beginUpdates()
        tableView.reloadSections(IndexSet(arrayLiteral: NetworkSettingsSection.kaltiot.rawValue), with: .automatic)
        tableView.endUpdates()
    }
    @objc func didEndEditingApiKey(_ sender: UITextField) {
        output.viewDidEnterApiKey(sender.text)
    }
}
