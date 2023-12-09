import RuuviLocalization
import UIKit
import Foundation

class RuuviCloudTableViewController: UITableViewController {
    var output: RuuviCloudViewOutput!
    var viewModels = [RuuviCloudViewModel]() {
        didSet {
            updateUI()
        }
    }

    init() {
        super.init(style: .grouped)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let reuseIdentifier: String = "reuseIdentifier"
}

// MARK: - LIFECYCLE
extension RuuviCloudTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

extension RuuviCloudTableViewController: RuuviCloudViewInput {
    func localize() {
        self.title = RuuviLocalization.ruuviCloud
    }
}

extension RuuviCloudTableViewController {
    fileprivate func setUpUI() {
        view.backgroundColor = RuuviColor.ruuviPrimary
        setUpTableView()
    }

    fileprivate func setUpTableView() {
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.register(RuuviCloudTableViewCell.self,
                           forCellReuseIdentifier: reuseIdentifier)
    }

    fileprivate func updateUI() {
        if isViewLoaded {
            DispatchQueue.main.async(execute: { [weak self] in
                self?.tableView.reloadData()
            })
        }
    }
}

// MARK: - UITableViewDataSource
extension RuuviCloudTableViewController {

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModels.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? RuuviCloudTableViewCell else {
            fatalError()
        }
        let viewModel = viewModels[indexPath.row]
        cell.configure(title: viewModel.title, value: viewModel.boolean.value)
        cell.delegate = self
        return cell
    }

    override func tableView(_ tableView: UITableView, estimatedHeightForFooterInSection section: Int) -> CGFloat {
        return 100
    }

    override func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let footerView = UIView()
        let footerLabel = UILabel()
        footerLabel.textColor = RuuviColor.ruuviTextColor
        footerLabel.font = UIFont.Muli(.regular, size: 13)
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
