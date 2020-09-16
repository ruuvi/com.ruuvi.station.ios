import UIKit

class SelectionTableViewController: UITableViewController {
    var output: SelectionViewOutput!
    var settings: Settings!
    @IBOutlet weak var descriptionTextView: UITextView!

    var viewModel: SelectionViewModel? {
        didSet {
            updateUI()
        }
    }

    private let cellReuseIdentifier = "SelectionTableViewCellReuseIdentifier"
}

// MARK: - SelectionViewInput
extension SelectionTableViewController: SelectionViewInput {
    func localize() {
        tableView.reloadData()
    }
}

// MARK: - View lifecycle
extension SelectionTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        setupLocalization()
    }
}

// MARK: - UITableViewDataSource
extension SelectionTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.items.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = viewModel?.items[indexPath.row],
              let cell = tableView
                .dequeueReusableCell(withIdentifier: cellReuseIdentifier,
                                     for: indexPath) as? SelectionTableViewCell else {
            return .init()
        }
        if let humidityUnit = item as? HumidityUnit, humidityUnit == .dew {
            cell.nameLabel.text = String(format: item.title, settings.temperatureUnit.symbol)
        } else {
            cell.nameLabel.text = item.title
        }
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SelectionTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        output.viewDidSelect(itemAtIndex: indexPath.row)
    }
}

// MARK: - Update UI
extension SelectionTableViewController {
    private func updateUI() {
        title = viewModel?.title
        if isViewLoaded {
            descriptionTextView.text = viewModel?.description
        }
        updateUISelections()
    }

    private func updateUISelections() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}
