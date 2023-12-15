import RuuviLocalization
import UIKit

extension ShareViewController {
    enum Section: Int {
        case addFriend = 0
        case sharedEmails
        case description

        init(value: Int) {
            switch value {
            case 0:
                self = .addFriend
            case 1:
                self = .sharedEmails
            case 2:
                self = .description
            default:
                fatalError()
            }
        }

        var title: ((Int, Int) -> String)? {
            switch self {
            case .description:
                nil
            case .addFriend: { _, _ in RuuviLocalization.ShareViewController.AddFriend.title }
            case .sharedEmails: { a, b in RuuviLocalization.ShareViewController.SharedEmails.title(a, b) }
            }
        }
    }
}

class ShareViewController: UITableViewController {
    var output: ShareViewOutput!
    var viewModel: ShareViewModel!

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = RuuviAssets.backButtonImage
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
        setupCustomBackButton()
        localize()
        output.viewDidLoad()
    }

    // MARK: - TableView

    override func numberOfSections(in _: UITableView) -> Int {
        if let canShare = viewModel.canShare.value, canShare {
            if viewModel.sharedEmails.value?.isEmpty == true {
                2
            } else {
                3
            }
        } else {
            1
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(value: section) {
        case .description:
            1
        case .addFriend:
            2
        case .sharedEmails:
            viewModel.sharedEmails.value?.count ?? 0
        }
    }

    override func tableView(
        _: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let section = Section(value: section)
        let headerView = UIView(color: .clear)
        let titleLabel = UILabel()
        titleLabel.textColor = RuuviColor.menuTextColor.color
        titleLabel.font = UIFont.Muli(.bold, size: 16)
        titleLabel.numberOfLines = 0
        switch section {
        case .sharedEmails:
            if let count = viewModel.sharedEmails.value?.count,
               let title = section.title {
                titleLabel.text = title(count, viewModel.maxCount)
            }
        default:
            titleLabel.text = section.title?(0, 0)
        }
        headerView.addSubview(titleLabel)
        titleLabel.fillSuperviewToSafeArea(
            padding: .init(
                top: 0,
                left: 20,
                bottom: 8,
                right: 20
            )
        )
        return headerView
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = switch Section(value: indexPath.section) {
        case .description:
            getDescriptionCell(tableView, indexPath: indexPath)
        case .addFriend:
            if indexPath.row == 0 {
                getAddFriendCell(tableView, indexPath: indexPath)
            } else {
                getButtonCell(tableView, indexPath: indexPath)
            }
        case .sharedEmails:
            getSharedEmailCell(tableView, indexPath: indexPath)
        }
        return cell
    }
}

// MARK: - ShareViewInput

extension ShareViewController: ShareViewInput {
    func localize() {
        title = RuuviLocalization.ShareViewController.title
    }

    func reloadTableView() {
        tableView.reloadData()
    }

    func clearInput() {
        let indexPath = IndexPath(row: 0, section: Section.addFriend.rawValue)
        guard let cell = tableView.cellForRow(at: indexPath) as? ShareEmailInputTableViewCell
        else {
            return
        }
        cell.emailTextField.text = nil
    }

    func showInvalidEmail() {
        showAlert(
            title: nil,
            message: RuuviLocalization.UserApiError.erInvalidEmailAddress
        )
    }

    func showSuccessfullyShared() {
        showAlert(
            title: nil,
            message: RuuviLocalization.Share.Success.message
        )
    }

    func showSuccessfullyInvited() {
        showAlert(
            title: RuuviLocalization.sharePending,
            message: RuuviLocalization.sharePendingMessage
        )
    }
}

extension ShareViewController: ShareEmailTableViewCellDelegate {
    func didTapUnshare(for email: String) {
        output.viewDidTapUnshareEmail(email)
    }
}

extension ShareViewController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_: UITextField) {
        tableView.scrollToBottom()
    }

    func textFieldShouldReturn(_: UITextField) -> Bool {
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
        let cell = tableView.dequeueReusableCell(
            with: ShareDescriptionTableViewCell.self,
            for: indexPath
        )
        if let canShare = viewModel.canShare.value, canShare {
            cell.sharingDisabledLabel.text = ""
        } else {
            cell.sharingDisabledLabel.text = RuuviLocalization.networkSharingDisabled
        }
        cell.sharingDisabledLabel.textColor = RuuviColor.textColor.color

        let description = RuuviLocalization.ShareViewController.description
        cell.descriptionLabel.text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        cell.descriptionLabel.textColor = RuuviColor.textColor.color
        return cell
    }

    private func getAddFriendCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailInputTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailInputTableViewCell.self, for: indexPath)
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        cell.emailTextField.placeholder = RuuviLocalization.ShareViewController.EmailTextField.placeholder
        cell.emailTextField.delegate = self
        cell.emailTextField.textColor = RuuviColor.textColor.color
        return cell
    }

    private func getButtonCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareSendButtonTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareSendButtonTableViewCell.self, for: indexPath)
        cell.sendButton.addTarget(self, action: #selector(didTapSendButton(_:)), for: .touchUpInside)
        cell.sendButton.setTitle(RuuviLocalization.TagSettings.Share.title, for: .normal)
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    private func getSharedEmailCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailTableViewCell.self, for: indexPath)
        cell.emailLabel.text = viewModel.sharedEmails.value?[indexPath.row]
        cell.emailLabel.textColor = RuuviColor.textColor.color
        cell.unshareButton.tintColor = RuuviColor.textColor.color
        cell.delegate = self
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    @objc private func didTapSendButton(_: UIButton) {
        guard let cell = tableView.cellForRow(at: IndexPath(
            row: 0,
            section: Section.addFriend.rawValue
        ))
            as? ShareEmailInputTableViewCell
        else {
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
        backButton.anchor(
            top: backBarButtonItemView.topAnchor,
            leading: backBarButtonItemView.leadingAnchor,
            bottom: backBarButtonItemView.bottomAnchor,
            trailing: backBarButtonItemView.trailingAnchor,
            padding: .init(top: 0, left: -12, bottom: 0, right: 0),
            size: .init(width: 40, height: 40)
        )
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: backBarButtonItemView)
    }

    @objc private func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }
}

extension UITableView {
    func scrollToBottom() {
        let numberOfSections = numberOfSections
        if numberOfSections > 0 {
            let numberOfRows = numberOfRows(inSection: numberOfSections - 1)
            if numberOfRows > 0 {
                let indexPath = IndexPath(row: numberOfRows - 1, section: numberOfSections - 1)
                scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
}
