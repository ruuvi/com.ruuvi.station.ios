import RuuviLocalization
import Foundation
import UIKit

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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let reuseIdentifier: String = "reuseIdentifier"
}

// MARK: - LIFECYCLE

extension AppearanceSettingsTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output.viewDidLoad()
    }
}

extension AppearanceSettingsTableViewController: AppearanceSettingsViewInput {
    func localize() {
        // no op.
    }
}

private extension AppearanceSettingsTableViewController {
    func setUpUI() {
        view.backgroundColor = RuuviColor.primary.color
        setUpTableView()
    }

    func setUpTableView() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(
            AppearanceSettingsTableViewBasicCell.self,
            forCellReuseIdentifier: reuseIdentifier
        )
    }

    func updateUI() {
        if isViewLoaded {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension AppearanceSettingsTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? AppearanceSettingsTableViewBasicCell
        else {
            fatalError()
        }
        let viewModel = viewModels[indexPath.row]
        cell.configure(title: viewModel.title, value: viewModel.selection.title(""))
        return cell
    }
}

// MARK: - UITableViewDelegate

extension AppearanceSettingsTableViewController {
    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        let viewModel = viewModels[indexPath.row]
        output.viewDidTriggerViewModel(viewModel: viewModel)
    }
}
