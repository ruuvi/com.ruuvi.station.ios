import Foundation
import RuuviLocalization
import UIKit

class RuuviCloudTableViewController: UITableViewController {
    var output: RuuviCloudViewOutput!
    var viewModels = [RuuviCloudViewModel]() {
        didSet {
            updateUI()
        }
    }

    init() {
        super.init(style: .plain)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let reuseIdentifier: String = "reuseIdentifier"
}

// MARK: - LIFECYCLE

extension RuuviCloudTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

extension RuuviCloudTableViewController: RuuviCloudViewInput {
    func localize() {
        title = RuuviLocalization.ruuviCloud
    }
}

private extension RuuviCloudTableViewController {
    func setUpUI() {
        view.backgroundColor = RuuviColor.primary.color
        setUpTableView()
    }

    func setUpTableView() {
        tableView.tableHeaderView = UIView()
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(
            RuuviCloudTableViewCell.self,
            forCellReuseIdentifier: reuseIdentifier
        )
    }

    func updateUI() {
        if isViewLoaded {
            DispatchQueue.main.async { [weak self] in
                self?.tableView.reloadData()
            }
        }
    }
}

// MARK: - UITableViewDataSource

extension RuuviCloudTableViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        viewModels.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? RuuviCloudTableViewCell
        else {
            fatalError()
        }
        let viewModel = viewModels[indexPath.row]
        cell.configure(
            title: viewModel.title,
            value: viewModel.boolean.value,
            hideStatusLabel: viewModel.hideStatusLabel.value ?? false
        )
        cell.delegate = self
        return cell
    }

    override func tableView(_: UITableView, estimatedHeightForFooterInSection _: Int) -> CGFloat {
        100
    }

    override func tableView(_: UITableView, viewForFooterInSection _: Int) -> UIView? {
        let footerView = UIView()
        let footerLabel = UILabel()
        footerLabel.textColor = RuuviColor.textColor.color.withAlphaComponent(0.6)
        footerLabel.font = UIFont.ruuviFootnote()
        footerLabel.numberOfLines = 0
        footerLabel.text = RuuviLocalization.Settings.Label.CloudMode.description
        footerView.addSubview(footerLabel)
        footerLabel.fillSuperview(padding: .init(top: 8, left: 20, bottom: 8, right: 20))
        return footerView
    }
}

// MARK: - RuuviCloudTableViewCellDelegate

extension RuuviCloudTableViewController: RuuviCloudTableViewCellDelegate {
    func didToggleSwitch(isOn: Bool, sender: RuuviCloudTableViewCell) {
        if let indexPath = tableView.indexPath(for: sender) {
            viewModels[indexPath.row].boolean.value = isOn
        }
    }
}
