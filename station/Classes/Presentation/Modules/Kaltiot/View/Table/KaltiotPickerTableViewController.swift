import UIKit

class KaltiotPickerTableViewController: UITableViewController {
    var output: KaltiotPickerViewOutput!
    var viewModel: KaltiotPickerViewModel!

    @IBOutlet weak var searchBar: UISearchBar! {
        didSet {
            searchBar.delegate = self
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        tableView.keyboardDismissMode = .onDrag
        if #available(iOS 11.0, *) {
            navigationItem.hidesSearchBarWhenScrolling = false
        }
        output.viewDidLoad()
    }
// MARK: - Table view data source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel?.beacons.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: KaltiotPickerTableViewCell.self, for: indexPath)
        let model = viewModel.beacons[indexPath.row].value
        cell.configure(with: model)
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            willDisplay cell: UITableViewCell,
                            forRowAt indexPath: IndexPath) {
        if indexPath.row == viewModel.beacons.count - 2 {
            output.viewDidTriggerLoadNextPage()
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let beacon = viewModel.beacons[indexPath.row].value
        output.viewDidSelectBeacon(beacon)
    }
// MARK: - IBActions
    @IBAction func didTapCloseButton(_ sender: Any) {
        output.viewDidTriggerClose()
    }
}
// MARK: - KaltiotPickerViewInput
extension KaltiotPickerTableViewController: KaltiotPickerViewInput {
    func localize() {
        title = "KaltiotPicker.Title.text".localized()
    }

    func applyChanges(_ changes: CellChanges) {
        if #available(iOS 11.0, *) {
            tableView.performBatchUpdates({
                tableView.reloadRows(at: changes.reloads, with: .fade)
                tableView.insertRows(at: changes.inserts, with: .fade)
                tableView.deleteRows(at: changes.deletes, with: .fade)
            }, completion: nil)
        } else {
            tableView.beginUpdates()
            tableView.reloadRows(at: changes.reloads, with: .fade)
            tableView.insertRows(at: changes.inserts, with: .fade)
            tableView.deleteRows(at: changes.deletes, with: .fade)
            tableView.endUpdates()
        }
    }
}
// MARK: - UISearchBarDelegate
extension KaltiotPickerTableViewController: UISearchBarDelegate {

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        doSearch(text: searchBar.text)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.text = nil
        output.viewDidCancelSearch()
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchBar.text = searchText.lowercased()
        doSearch(text: searchText)
    }

    func searchBar(_ searchBar: UISearchBar, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        guard !text.isEmpty else {
            return true
        }
        let searchText = searchBar.text ?? ""
        return text.allSatisfy({ $0.isHexDigit })
            && searchText.allSatisfy({ $0.isHexDigit }) && searchText.count < 12
    }
}
// MARK: - Private
extension KaltiotPickerTableViewController {
    func doSearch(text: String?) {
        guard let text = text else {
            output.viewDidCancelSearch()
            return
        }
        output.viewDidStartSearch(mac: text)
    }
}
