import RuuviLocalization
import UIKit

extension ShareViewController {
    enum Section: Int {
        case addFriend = 0
        case shareSummary
        case sharedEmails
        case pendingSharedEmails
        case description

        init(
            value: Int,
            pendingSharedEmailsExist: Bool
        ) {
            switch (pendingSharedEmailsExist, value) {
            case (_, 0):
                self = .addFriend
            case (_, 1):
                self = .shareSummary
            case (_, 2):
                self = .sharedEmails
            case (true, 3):
                self = .pendingSharedEmails
            case (false, 3),
                 (true, 4):
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
            case .shareSummary:
                nil
            case .sharedEmails: { _, _ in RuuviLocalization.shareActiveAccessSectionTitle }
            case .pendingSharedEmails: { _, _ in RuuviLocalization.sharePendingSectionTitle }
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
        let buttonImage = RuuviAsset.chevronBack.image
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
        if #unavailable(iOS 26) {
            setupCustomBackButton()
        }
        localize()
        styleViews()
        output.viewDidLoad()
    }

    private func styleViews() {
        view.backgroundColor = RuuviColor.primary.color
    }

    // MARK: - TableView

    override func numberOfSections(in _: UITableView) -> Int {
        if let canShare = viewModel.canShare.value, canShare {
            4 + (viewModel.pendingSharedToCount > 0 ? 1 : 0)
        } else {
            1
        }
    }

    override func tableView(_: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(
            value: section,
            pendingSharedEmailsExist: viewModel.pendingSharedToCount > 0
        ) {
        case .description:
            1
        case .addFriend:
            2
        case .shareSummary:
            0
        case .sharedEmails:
            max(viewModel.sharedEmails.value?.count ?? 0, 1)
        case .pendingSharedEmails:
            viewModel.pendingSharedEmails.value?.count ?? 0
        }
    }

    override func tableView(
        _: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let section = Section(
            value: section,
            pendingSharedEmailsExist: viewModel.pendingSharedToCount > 0
        )
        let titleText: String? = switch section {
        case .shareSummary:
            RuuviLocalization.shareSensorSharedToCountMessage(
                viewModel.totalShareCount,
                viewModel.sensorMaxCount,
                viewModel.planTotalUsedCount,
                viewModel.planTotalAvailableCount
            )
        case .pendingSharedEmails:
            section.title?(0, 0)
        default:
            section.title?(0, 0)
        }
        guard let titleText, !titleText.isEmpty else {
            return nil
        }
        let headerView = UIView(color: .clear)
        let titleLabel = UILabel()
        titleLabel.textColor = RuuviColor.menuTextColor.color
        titleLabel.font = UIFont.ruuviCallout()
        titleLabel.numberOfLines = 0
        titleLabel.text = titleText
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

    override func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let section = Section(
            value: section,
            pendingSharedEmailsExist: viewModel.pendingSharedToCount > 0
        )
        let titleText: String? = switch section {
        case .shareSummary:
            RuuviLocalization.shareSensorSharedToCountMessage(
                viewModel.totalShareCount,
                viewModel.sensorMaxCount,
                viewModel.planTotalUsedCount,
                viewModel.planTotalAvailableCount
            )
        case .pendingSharedEmails:
            section.title?(0, 0)
        default:
            section.title?(0, 0)
        }
        return (titleText?.isEmpty == false) ? UITableView.automaticDimension : .leastNormalMagnitude
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = switch Section(
            value: indexPath.section,
            pendingSharedEmailsExist: viewModel.pendingSharedToCount > 0
        ) {
        case .description:
            getDescriptionCell(tableView, indexPath: indexPath)
        case .addFriend:
            if indexPath.row == 0 {
                getAddFriendCell(tableView, indexPath: indexPath)
            } else {
                getButtonCell(tableView, indexPath: indexPath)
            }
        case .shareSummary:
            UITableViewCell()
        case .sharedEmails:
            getSharedEmailCell(tableView, indexPath: indexPath)
        case .pendingSharedEmails:
            getPendingSharedEmailCell(tableView, indexPath: indexPath)
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
        tableView.sectionFooterHeight = .leastNormalMagnitude
        tableView.estimatedSectionFooterHeight = .leastNormalMagnitude
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
        cell.sharingDisabledLabel.font = UIFont.ruuviCallout()
        cell.sharingDisabledLabel.textColor = RuuviColor.textColor.color
        cell.sharingDisabledLabel.tintColor = RuuviColor.tintColor.color

        let description = RuuviLocalization.ShareViewController.description
        cell.descriptionLabel.text = description.trimmingCharacters(in: .whitespacesAndNewlines)
        cell.descriptionLabel.textColor = RuuviColor.textColor.color
        cell.descriptionLabel.tintColor = RuuviColor.tintColor.color
        cell.descriptionLabel.font = UIFont.ruuviFootnote()
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    private func getAddFriendCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailInputTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailInputTableViewCell.self, for: indexPath)
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        cell.emailTextField.placeholder = RuuviLocalization.ShareViewController.EmailTextField.placeholder
        cell.emailTextField.delegate = self
        cell.emailTextField.textColor = RuuviColor.textColor.color
        cell.emailTextField.font = UIFont.ruuviBody()
        return cell
    }

    private func getButtonCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareSendButtonTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareSendButtonTableViewCell.self, for: indexPath)
        cell.sendButton.addTarget(self, action: #selector(didTapSendButton(_:)), for: .touchUpInside)
        cell.sendButton.setTitle(RuuviLocalization.TagSettings.Share.title, for: .normal)
        cell.sendButton.tintColor = RuuviColor.tintColor.color
        cell.sendButton.titleLabel?.font = UIFont.ruuviButtonMedium()
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    private func getSharedEmailCell(_ tableView: UITableView, indexPath: IndexPath) -> ShareEmailTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailTableViewCell.self, for: indexPath)
        let sharedEmails = viewModel.sharedEmails.value ?? []
        let email = sharedEmails.indices.contains(indexPath.row)
            ? sharedEmails[indexPath.row]
            : nil
        cell.emailLabel.text = email ?? RuuviLocalization.shareActiveAccessEmptyValue
        cell.emailLabel.textColor = RuuviColor.textColor.color
        cell.emailLabel.font = UIFont.ruuviBody()
        cell.unshareButton.tintColor = RuuviColor.textColor.color
        cell.unshareButton.setImage(RuuviAsset.smallCrossClearIcon.image, for: .normal)
        cell.unshareButton.isHidden = email == nil
        cell.unshareButton.isUserInteractionEnabled = email != nil
        cell.delegate = email == nil ? nil : self
        cell.separatorInset = UIEdgeInsets(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }

    private func getPendingSharedEmailCell(
        _ tableView: UITableView,
        indexPath: IndexPath
    ) -> ShareEmailTableViewCell {
        let cell = tableView.dequeueReusableCell(with: ShareEmailTableViewCell.self, for: indexPath)
        cell.emailLabel.text = viewModel.pendingSharedEmails.value?[indexPath.row]
        cell.emailLabel.textColor = RuuviColor.textColor.color
        cell.emailLabel.font = UIFont.ruuviBody()
        cell.unshareButton.tintColor = RuuviColor.textColor.color
        cell.unshareButton.setImage(RuuviAsset.smallCrossClearIcon.image, for: .normal)
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
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
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
