import UIKit
extension ShareViewController {
    enum Section: Int {
        case description = 0
        case addFriend
        case sharedEmails

        init(value: Int) {
            switch value {
            case 0:
                self = .description
            case 1:
                self = .addFriend
            case 2:
                self = .sharedEmails
            default:
                fatalError()
            }
        }

        var title: String? {
            switch self {
            case .description:
                return nil
            case .addFriend:
                return "ShareViewController.addFriend.Title".localized()
            case .sharedEmails:
                return "ShareViewController.sharedEmails.Title".localized()
            }
        }
    }
}
class ShareViewController: UITableViewController {
    var output: ShareViewOutput!
    var viewModel: ShareViewModel!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        setupLocalization()
        output.viewDidLoad()
    }

    // MARK: - TableView

    override func numberOfSections(in tableView: UITableView) -> Int {
        if viewModel.sharedEmails.value?.isEmpty == true {
            return 2
        } else {
            return 3
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(value: section) {
        case .description:
            return 1
        case .addFriend:
            return 2
        case .sharedEmails:
            return viewModel.sharedEmails.value?.count ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let section = Section(value: section)
        switch section {
        case .sharedEmails:
            if let count = viewModel.sharedEmails.value?.count,
               let title = section.title {
                return String(format: title, count, viewModel.maxCount)
            } else {
                return nil
            }
        default:
            return section.title
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return section > 0 ? 44 : 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell
        switch Section(value: indexPath.section) {
        case .description:
            cell = getDescriptionCell(tableView, indexPath: indexPath)
        case .addFriend:
            if indexPath.row == 0 {
                cell = getAddFriendCell(tableView, indexPath: indexPath)
            } else {
                cell = getButtonCell(tableView, indexPath: indexPath)
            }
        case .sharedEmails:
            cell = getSharedEmailCell(tableView, indexPath: indexPath)
        }
        return cell
    }
}

// MARK: - ShareViewInput
extension ShareViewController: ShareViewInput {
    func localize() {
        title = "ShareViewController.Title".localized()
    }

    func reloadTableView() {
        tableView.reloadData()
    }

    func clearInput() {
        let indexPath: IndexPath = IndexPath(row: 0, section: Section.addFriend.rawValue)
        guard let cell = tableView.cellForRow(at: indexPath) as? ShareEmailInputTableViewCell else {
            return
        }
        cell.emailTextField.text = nil
    }
}
extension ShareViewController: ShareEmailTableViewCellDelegate {
    func didTapUnshare(for email: String) {
        output.viewDidTapUnshareEmail(email)
    }
}
// MARK: - Private
extension ShareViewController {
    func configureTableView() {
        tableView.tableFooterView = UIView(frame: .zero)
    }

    private func getDescriptionCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareDescriptionTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareDescriptionTableViewCell.self, for: indexPath)
        let description = String(format: "ShareViewController.Description".localized(), viewModel.maxCount)
        cell.descriptionLabel.text = description
        if #available(iOS 13.0, *) {
            cell.descriptionLabel.textColor = .secondaryLabel
        } else {
            cell.descriptionLabel.textColor = UIColor(red: 138.0/255.0,
                                                      green: 138.0/255.0,
                                                      blue: 142.0/255.0,
                                                      alpha: 1.0)
        }
        return cell
    }

    private func getAddFriendCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailInputTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailInputTableViewCell.self, for: indexPath)
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        cell.emailTextField.placeholder = "ShareViewController.emailTextField.placeholder".localized()
        return cell
    }

    private func getButtonCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareSendButtonTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareSendButtonTableViewCell.self, for: indexPath)
        cell.sendButton.addTarget(self, action: #selector(didTapSendButton(_:)), for: .touchUpInside)
        cell.sendButton.setTitle("Share.Send.button".localized(), for: .normal)
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    private func getSharedEmailCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailTableViewCell.self, for: indexPath)
        cell.emailLabel.text = viewModel.sharedEmails.value?[indexPath.row]
        cell.delegate = self
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    @objc private func didTapSendButton(_ sender: UIButton) {
        guard let cell = tableView.cellForRow(at: IndexPath(row: 0,
                                                            section: Section.addFriend.rawValue))
                as? ShareEmailInputTableViewCell else {
            return
        }
        cell.emailTextField.endEditing(true)
        output.viewDidTapSendButton(
            email: cell.emailTextField.text?.trimmingCharacters(in: .whitespaces)
        )
    }
}
