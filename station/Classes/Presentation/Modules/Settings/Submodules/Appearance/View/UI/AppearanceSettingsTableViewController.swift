import UIKit
import Foundation

class AppearanceSettingsTableViewController: UITableViewController {
    var output: AppearanceSettingsViewOutput!
    var viewModels = [AppearanceSettingsViewModel]() {
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

    private let reuseIdentifier: String = "reuseIdentifier"
}

// MARK: - LIFECYCLE
extension AppearanceSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        output.viewDidLoad()
    }
}

extension AppearanceSettingsTableViewController: AppearanceSettingsViewInput {
    func localize() {
        // no op.
    }
}

extension AppearanceSettingsTableViewController {
    fileprivate func setUpUI() {
        view.backgroundColor = RuuviColor.ruuviPrimary
        setUpTableView()
    }

    fileprivate func setUpTableView() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(AppearanceSettingsTableViewBasicCell.self,
                           forCellReuseIdentifier: reuseIdentifier)
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
extension AppearanceSettingsTableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? AppearanceSettingsTableViewBasicCell else {
            fatalError()
        }
        let viewModel = viewModels[indexPath.row]
        cell.configure(title: viewModel.title, value: viewModel.selection.title(""))
        return cell
    }
}

// MARK: - UITableViewDelegate
extension AppearanceSettingsTableViewController {
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = viewModels[indexPath.row]
        output.viewDidTriggerViewModel(viewModel: viewModel)
    }
}
