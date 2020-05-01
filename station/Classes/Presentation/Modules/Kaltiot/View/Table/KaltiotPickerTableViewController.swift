import UIKit

class KaltiotPickerTableViewController: UITableViewController {
    var output: KaltiotPickerViewOutput!
    var viewModel: KaltiotPickerViewModel!

// MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
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
        output.viewDidSelectTag(at: indexPath.row)
    }
// MARK: - IBActions
    @IBAction func didTapCloseButton(_ sender: Any) {
        output.viewDidTriggerClose()
    }
}
// MARK: - KaltiotPickerViewInput
extension KaltiotPickerTableViewController: KaltiotPickerViewInput {
    func localize() {
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
