import UIKit
import Foundation
import RuuviLocalization

class NotificationsSettingsTableViewController: UITableViewController {
    var output: NotificationsSettingsViewOutput?
    var viewModels = [NotificationsSettingsViewModel]() {
        didSet {
            updateUI()
        }
    }

    init(title: String) {
        super.init(style: .grouped)
        self.title = title
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let reuseIdentifierTextCell: String = "reuseIdentifierTextCell"
    private static let reuseIdentifierSwitchCell: String = "reuseIdentifierSwitchCell"
}

// MARK: - LIFECYCLE
extension NotificationsSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        output?.viewDidLoad()
    }
}

extension NotificationsSettingsTableViewController: NotificationsSettingsViewInput {
    func localize() {
            // no op.
    }
}

extension NotificationsSettingsTableViewController {
    fileprivate func setUpUI() {
        view.backgroundColor = RuuviColor.ruuviPrimary
        setUpTableView()
    }

    fileprivate func setUpTableView() {
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(
            NotificationsSettingsTextCell.self,
            forCellReuseIdentifier: Self.reuseIdentifierTextCell
        )
        tableView.register(
            NotificationsSettingsSwitchCell.self,
            forCellReuseIdentifier: Self.reuseIdentifierSwitchCell
        )
    }

    fileprivate func updateUI() {
        if isViewLoaded {
            DispatchQueue.main.async(execute: { [weak self] in
                self?.tableView.reloadData()
            })
        }
    }
}

    // MARK: - UITableViewDataSource
extension NotificationsSettingsTableViewController {

    override func tableView(_ tableView: UITableView,
                            numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let viewModel = viewModels[indexPath.row]
        switch viewModel.configType.value {
        case .plain:
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: Self.reuseIdentifierTextCell,
                for: indexPath
            ) as? NotificationsSettingsTextCell else {
                fatalError()
            }
            cell.configure(
                title: viewModel.title,
                subtitle: viewModel.subtitle,
                value: viewModel.value.value
            )
            return cell
        case .switcher:
            guard let cell = tableView.dequeueReusableCell(
                withIdentifier: Self.reuseIdentifierSwitchCell,
                for: indexPath
            ) as? NotificationsSettingsSwitchCell else {
                fatalError()
            }
            cell.configure(
                title: viewModel.title,
                subtitle: viewModel.subtitle,
                value: viewModel.boolean.value
            )
            cell.delegate = self
            return cell
        default:
            return UITableViewCell()
        }

    }

    override func tableView(_ tableView: UITableView,
                            estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return 100
    }

    override func tableView(_ tableView: UITableView,
                            viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        let footerTextView = RuuviLinkTextView(
            fullTextString: RuuviLocalization.settingsAlertsFooterDescription,
            linkString: RuuviLocalization.settingsAlertsFooterDescriptionLinkMask,
            link: UIApplication.openSettingsURLString
        )
        footerTextView.linkDelegate = self
        footerView.addSubview(footerTextView)
        footerTextView.fillSuperview(padding: .init(top: 0, left: 16, bottom: 0, right: 16))
        return footerView
    }
}

// MARK: - UITableViewDelegate
extension NotificationsSettingsTableViewController {
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = viewModels[indexPath.row]
        switch viewModel.settingsType.value {
        case .alertSound:
            output?.viewDidTapSoundSelection()
        default:
            break
        }
    }
}

// MARK: - NotificationsSettingsSwitchCellDelegate
extension NotificationsSettingsTableViewController: NotificationsSettingsSwitchCellDelegate {
    func didToggleSwitch(isOn: Bool, sender: NotificationsSettingsSwitchCell) {
        if let indexPath = tableView.indexPath(for: sender) {
            viewModels[indexPath.row].boolean.value = isOn
        }
    }
}

extension NotificationsSettingsTableViewController: RuuviLinkTextViewDelegate {
    func didTapLink(url: String) {
        guard let settingsURL = URL(string: url) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }
}
