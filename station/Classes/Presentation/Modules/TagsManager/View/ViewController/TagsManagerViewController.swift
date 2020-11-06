import UIKit

extension TagsManagerViewController {
    enum Sections: Int, CaseIterable {
//        case userInfo = 0
        case sharedTags = 0
        case actions

        init(_ section: Int) {
            guard let sectionType = Sections(rawValue: section) else {
                fatalError()
            }
            self = sectionType
        }
    }
}

class TagsManagerViewController: UIViewController {
    var output: TagsManagerViewOutput!
    var viewModel: TagsManagerViewModel! {
        didSet {
            bindViewModel()
        }
    }

    @IBOutlet weak var tableView: UITableView! {
        didSet {
            tableView.tableFooterView = UIView()
        }
    }

    @IBOutlet weak var signOutBarButtonItem: UIBarButtonItem!
    private var items: [TagManagerCellViewModel] = [] {
        didSet {
            if self.isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    private var actions: [TagManagerActionType] = [] {
        didSet {
            if self.isViewLoaded {
                tableView.reloadData()
            }
        }
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        output.viewDidLoad()
    }

    @IBAction func didSignOutButtonTap(_ sender: UIBarButtonItem) {
        output.viewDidSignOutButtonTap()
    }

    @IBAction func didCloseButtonTap(_ sender: UIBarButtonItem) {
        output.viewDidCloseButtonTap()
    }
}

// MARK: - TagsManagerViewInput
extension TagsManagerViewController: TagsManagerViewInput {
    func localize() {
        signOutBarButtonItem.title = "TagsManager.SignOutButton".localized()
        
    }
}

// MARK: - Private
extension TagsManagerViewController {
    private func bindViewModel() {
        bind(viewModel.title) { (viewController, title) in
            viewController.title = title
        }
        bind(viewModel.items) { (viewController, items) in
            viewController.items = items ?? []
        }
        bind(viewModel.actions) { (viewController, actions) in
            viewController.actions = actions ?? []
        }
    }

    private func getTagCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: TagManagerTableViewCell.self, for: indexPath)
        let model = items[indexPath.row]
        cell.textLabel?.text = model.title
        cell.detailTextLabel?.text = model.subTitle
        return cell
    }

    private func getActionCell(_ tableView: UITableView, _ indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(with: TagManagerButtonTableViewCell.self, for: indexPath)
        let action = actions[indexPath.row]
        cell.actionType = action
        cell.button.setTitle(action.title, for: .normal)
        cell.output = self
        cell.separatorInset = .init(top: 0, left: tableView.bounds.width, bottom: 0, right: 0)
        return cell
    }
}
// MARK: - UITableViewDelegate
extension TagsManagerViewController: TagManagerButtonTableViewCellOutput {
    func tagManagerButtonCell(didTapButton action: TagManagerActionType) {
        output.viewDidTapAction(action)
    }
}
// MARK: - UITableViewDelegate
extension TagsManagerViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch Sections(indexPath.section) {
        case .actions:
            guard let action = viewModel.actions.value?[indexPath.row] else {
                return
            }
            output?.viewDidTapAction(action)
        default:
            break
        }
    }
}

// MARK: - UITableViewDataSource
extension TagsManagerViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Sections.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Sections(section) {
        case .sharedTags:
            return items.count
        case .actions:
            return actions.count
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Sections(section) {
//        case .userInfo:
//            return "TagsManager.UserInfo".localized()
        case .sharedTags:
            return "TagsManager.SharedTags".localized()
        case .actions:
            return "TagsManager.Actions".localized()
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        switch Sections(indexPath.section) {
        case .sharedTags:
            return getTagCell(tableView, indexPath)
        case .actions:
            return getActionCell(tableView, indexPath)

        }
    }
}
