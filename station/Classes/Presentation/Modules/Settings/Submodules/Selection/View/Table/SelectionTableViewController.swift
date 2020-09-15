import UIKit

class SelectionTableViewController: UITableViewController {
    var output: SelectionViewOutput!

    var items: [SelectionItemProtocol] = [SelectionItemProtocol]() {
        didSet {
            updateUISelections()
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
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView
            .dequeueReusableCell(withIdentifier: cellReuseIdentifier,
                                 for: indexPath) as! SelectionTableViewCell
        // swiftlint:enable force_cast
        cell.nameLabel.text = items[indexPath.row].title
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
        updateUISelections()
    }

    private func updateUISelections() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}
