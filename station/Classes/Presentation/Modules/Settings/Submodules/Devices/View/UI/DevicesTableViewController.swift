import UIKit

class DevicesTableViewController: UITableViewController {
    var output: DevicesViewOutput!
    var viewModels: [DevicesViewModel] = [] {
        didSet {
            updateUI()
        }
    }

    private let reuseIndentifier: String = "reuseIndentifier"

    init() {
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: LIFE CYCLE
extension DevicesTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
        setUpTableView()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

extension DevicesTableViewController: DevicesViewInput {
    func localize() {
        self.title = "DfuDevicesScanner.Title.text".localized()
    }

    func showTokenIdDialog(for viewModel: DevicesViewModel) {
        guard let tokenId = viewModel.id.value else {
            return
        }

        let title = "Token Id".localized()
        let controller = UIAlertController(title: title,
                                           message: tokenId.stringValue,
                                           preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Copy".localized(),
                                           style: .default,
                                           handler: { _ in
            UIPasteboard.general.string = tokenId.stringValue
        }))
        controller.addAction(UIAlertAction(title: "Cancel".localized(), style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showTokenFetchError(with error: RUError) {
        let controller = UIAlertController(title: nil,
                                           message: error.localizedDescription,
                                           preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Ok".localized(),
                                           style: .default,
                                           handler: { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }))
        present(controller, animated: true)
    }
}

extension DevicesTableViewController {
    fileprivate func updateUI() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }

    fileprivate func setUpTableView() {
        view.backgroundColor = RuuviColor.ruuviPrimary
        tableView.showsVerticalScrollIndicator = false
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50
        tableView.separatorStyle = .none

        tableView.register(DevicesTableViewCell.self,
                           forCellReuseIdentifier: reuseIndentifier)
    }
}

// MARK: - TABLEVIEW DATA SOURCE
extension DevicesTableViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: reuseIndentifier,
                                                       for: indexPath) as? DevicesTableViewCell else {
            fatalError()
        }
        cell.configure(with: viewModels[indexPath.row])
        return cell
    }
}

// MARK: - TABLEVIEW DELEGATE
extension DevicesTableViewController {
    override func tableView(_ tableView: UITableView,
                            didSelectRowAt indexPath: IndexPath) {
        output.viewDidTapDevice(viewModel: viewModels[indexPath.row])
    }
}
