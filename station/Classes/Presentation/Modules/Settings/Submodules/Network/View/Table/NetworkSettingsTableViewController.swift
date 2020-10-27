import UIKit

enum NetworkSettingsSection: Int, CaseIterable {
    case common

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

// MARK: - NetworkSettingsViewInput
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
        case .common:
            return networkFeatureEnabled ? 2 : 1
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch NetworkSettingsSection(indexPath: indexPath) {
        case .common:
            switch indexPath.row {
            case 0:
                return getNetworkTogglerCell(tableView, indexPath)
            case 1:
                return getNetworkStepperCell(tableView, indexPath)
            default:
                fatalError()
            }
        }
    }
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
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
}

extension NetworkSettingsTableViewController: NetworkSettingsStepperTableViewCellDelegate {
    func foregroundStepper(cell: NetworkSettingsStepperTableViewCell, didChange value: Int) {
        viewModel.networkRefreshInterval.value = value
    }
}

// MARK: - Private
extension NetworkSettingsTableViewController {
    private func getNetworkTogglerCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: NetworkSettingsSwitchTableViewCell.self, for: indexPath)
        cell.settingsSwitch.isOn = networkFeatureEnabled
        cell.settingsSwitch.addTarget(self,
                                      action: #selector(didChangeNetworkFeatureEnabled(_:)),
                                      for: .valueChanged)
        cell.settingsTitleLabel.text = "NetworkSettings.NetworkFeature".localized()
        return cell
    }

    private func getNetworkStepperCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: NetworkSettingsStepperTableViewCell.self, for: indexPath)
        if let minInterval = viewModel.minNetworkRefreshInterval.value {
            cell.stepper.minimumValue = minInterval
        }
        if let refreshInterval = viewModel.networkRefreshInterval.value {
            cell.stepper.value = Double(refreshInterval)
            cell.setTitle(withValue: refreshInterval)
        }
        cell.delegate = self
        return cell
    }
}
