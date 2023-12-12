import RuuviLocalization
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

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: LIFE CYCLE

extension DevicesTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpTableView()
        localize()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

extension DevicesTableViewController: DevicesViewInput {
    func localize() {
        title = RuuviLocalization.DfuDevicesScanner.Title.text
    }

    func showTokenIdDialog(for viewModel: DevicesViewModel) {
        guard let tokenId = viewModel.id.value
        else {
            return
        }

        let title = RuuviLocalization.Devices.tokenId
        let controller = UIAlertController(
            title: title,
            message: tokenId.stringValue,
            preferredStyle: .alert
        )
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.copy,
            style: .default,
            handler: { _ in
                UIPasteboard.general.string = tokenId.stringValue
            }
        ))
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showTokenFetchError(with error: RUError) {
        let controller = UIAlertController(
            title: nil,
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .default,
            handler: { [weak self] _ in
                self?.navigationController?.popViewController(animated: true)
            }
        ))
        present(controller, animated: true)
    }
}

private extension DevicesTableViewController {
    func updateUI() {
        DispatchQueue.main.async { [weak self] in
            self?.tableView.reloadData()
        }
    }

    func setUpTableView() {
        view.backgroundColor = RuuviColor.ruuviPrimary
        tableView.showsVerticalScrollIndicator = false
        tableView.tableFooterView = UIView()
        tableView.estimatedRowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50
        tableView.separatorStyle = .none

        tableView.register(
            DevicesTableViewCell.self,
            forCellReuseIdentifier: reuseIndentifier
        )
    }
}

// MARK: - TABLEVIEW DATA SOURCE

extension DevicesTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIndentifier,
            for: indexPath
        ) as? DevicesTableViewCell
        else {
            fatalError()
        }
        cell.configure(with: viewModels[indexPath.row])
        return cell
    }
}

// MARK: - TABLEVIEW DELEGATE

extension DevicesTableViewController {
    override func tableView(
        _: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        output.viewDidTapDevice(viewModel: viewModels[indexPath.row])
    }
}
