import UIKit

class LanguageTableViewController: UITableViewController {
    var output: LanguageViewOutput!

    var languages: [Language] = [Language]() {
        didSet {
            updateUILanguages()
        }
    }

    private let cellReuseIdentifier = "LanguageTableViewCellReuseIdentifier"
}

// MARK: - LanguageViewInput
extension LanguageTableViewController: LanguageViewInput {
    func localize() {
        tableView.reloadData()
    }
}

// MARK: - View lifecycle
extension LanguageTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        updateUI()
        setupLocalization()
        output.viewDidLoad()
    }
}

// MARK: - UITableViewDataSource
extension LanguageTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return languages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // swiftlint:disable force_cast
        let cell = tableView
            .dequeueReusableCell(withIdentifier: cellReuseIdentifier,
                                 for: indexPath) as! LanguageTableViewCell
        // swiftlint:enable force_cast
        cell.languageNameLabel.text = languages[indexPath.row].name
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LanguageTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        output.viewDidSelect(language: languages[indexPath.row])
    }
}

// MARK: - Update UI
extension LanguageTableViewController {
    private func updateUI() {
        updateUILanguages()
    }

    private func updateUILanguages() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }
}
