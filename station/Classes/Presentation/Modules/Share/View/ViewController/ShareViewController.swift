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

    private lazy var backButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .label
        let buttonImage = UIImage(named: "chevron_back")
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        configureTableView()
        setupLocalization()
        setupCustomBackButton()
        output.viewDidLoad()
    }

    // MARK: - TableView

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let canShare = viewModel.canShare.value, canShare {
            if viewModel.sharedEmails.value?.isEmpty == true {
                return 2
            } else {
                return 3
            }
        } else {
            return 1
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

//    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
//        let section = Section(value: section)
//        switch section {
//        case .sharedEmails:
//            if let count = viewModel.sharedEmails.value?.count,
//               let title = section.title {
//                return String(format: title, count, viewModel.maxCount)
//            } else {
//                return nil
//            }
//        default:
//            return section.title
//        }
//    }

    override func tableView(_ tableView: UITableView,
                            viewForHeaderInSection section: Int) -> UIView? {
        let section = Section(value: section)
        let headerView = UIView(color: .clear)
        let titleLabel = UILabel()
        titleLabel.textColor = RuuviColor.ruuviMenuTextColor
        titleLabel.font = UIFont.Muli(.bold, size: 16)
        titleLabel.numberOfLines = 0
        switch section {
        case .sharedEmails:
            if let count = viewModel.sharedEmails.value?.count,
               let title = section.title {
                titleLabel.text = String(format: title,
                                         count,
                                         viewModel.maxCount)
            }
        default:
            titleLabel.text = section.title
        }
        headerView.addSubview(titleLabel)
        titleLabel.fillSuperviewToSafeArea(
            padding: .init(top: 0, left: 20,
                           bottom: 8, right: 20)
        )
        return headerView
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

    func showInvalidEmail() {
        showAlert(
            title: nil,
            message: "UserApiError.ER_INVALID_EMAIL_ADDRESS".localized()
        )
    }

    func showSuccessfullyShared() {
        showAlert(
            title: nil,
            message: "Share.Success.message".localized()
        )
    }
}
extension ShareViewController: ShareEmailTableViewCellDelegate {
    func didTapUnshare(for email: String) {
        output.viewDidTapUnshareEmail(email)
    }
}
extension ShareViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_ textField: UITextField) {
        tableView.scrollToBottom()
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        view.endEditing(true)
        return true
    }
}

// MARK: - Private
extension ShareViewController {
    func configureTableView() {
        tableView.sectionHeaderHeight = UITableView.automaticDimension
        tableView.estimatedSectionHeaderHeight = 70
        tableView.tableFooterView = UIView(frame: .zero)
    }

    private func getDescriptionCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareDescriptionTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareDescriptionTableViewCell.self,
                                                 for: indexPath)
        if let canShare = viewModel.canShare.value, canShare {
            cell.sharingDisabledLabel.text = ""
        } else {
            cell.sharingDisabledLabel.text = "network_sharing_disabled".localized()
        }

        let description = "ShareViewController.Description".localized()
        cell.descriptionLabel.text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        cell.descriptionLabel.textColor = RuuviColor.ruuviTextColor
        return cell
    }

    private func getAddFriendCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailInputTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailInputTableViewCell.self, for: indexPath)
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        cell.emailTextField.placeholder = "ShareViewController.emailTextField.placeholder".localized()
        cell.emailTextField.delegate = self
        return cell
    }

    private func getButtonCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareSendButtonTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareSendButtonTableViewCell.self, for: indexPath)
        cell.sendButton.addTarget(self, action: #selector(didTapSendButton(_:)), for: .touchUpInside)
        cell.sendButton.setTitle("TagSettings.Share.title".localized(), for: .normal)
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

    private func setupCustomBackButton() {
        let backBarButtonItemView = UIView()
        backBarButtonItemView.addSubview(backButton)
        backButton.anchor(top: backBarButtonItemView.topAnchor,
                          leading: backBarButtonItemView.leadingAnchor,
                          bottom: backBarButtonItemView.bottomAnchor,
                          trailing: backBarButtonItemView.trailingAnchor,
                          padding: .init(top: 0, left: -8, bottom: 0, right: 0),
                          size: .init(width: 32, height: 32))
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    @objc fileprivate func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }
}

extension UITableView {
    func scrollToBottom() {
        let numberOfSections = self.numberOfSections
        if numberOfSections > 0 {
            let numberOfRows = self.numberOfRows(inSection: numberOfSections - 1)
            if numberOfRows > 0 {
                let indexPath = IndexPath(row: numberOfRows - 1, section: (numberOfSections - 1))
                self.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
}
