import Foundation
import RuuviLocalization
import UIKit

class ASSelectionTableViewController: UITableViewController {
    var output: ASSelectionViewOutput!
    var viewModel: AppearanceSettingsViewModel? {
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

extension ASSelectionTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output.viewDidLoad()
    }
}

extension ASSelectionTableViewController: ASSelectionViewInput {
    func localize() {
        // no op.
    }
}

private extension ASSelectionTableViewController {
    func setUpUI() {
        view.backgroundColor = RuuviColor.primary.color
        setUpTableView()
    }

    func setUpTableView() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(
            ASSelectionTableViewCell.self,
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

extension ASSelectionTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModel?.items.count ?? 0
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? ASSelectionTableViewCell
        else {
            fatalError()
        }
        if let viewModel {
            let item = viewModel.items[indexPath.row]
            cell.configure(
                title: item.title(""),
                selection: viewModel.selection.title("")
            )
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension ASSelectionTableViewController {
    override func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        if let viewModel {
            output.viewDidSelectItem(
                item: viewModel.items[indexPath.row],
                type: viewModel.type
            )
        }
    }
}
