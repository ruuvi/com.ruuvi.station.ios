import RuuviLocalization
import UIKit

final class FeatureTogglesViewController: UITableViewController {
    var featureToggleService: FeatureToggleService!

    init() {
        headerView = UIView()
        sourceSwitch = RuuviUISwitch()
        sourceLabel = Self.makeSourceLabel()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let headerView: UIView
    private let sourceSwitch: RuuviUISwitch
    private let sourceLabel: UILabel
    private let features = Feature.allCases
    private static let featureCellReuseIdentifier = "FeatureCellReuseIdentifier"

    private func setupViews() {
        view.backgroundColor = RuuviColor.primary.color
        headerView.addSubview(sourceSwitch)
        headerView.addSubview(sourceLabel)
        tableView.tableHeaderView = headerView
        sourceSwitch.addTarget(self, action: #selector(sourceSwitchValueChanged(_:)), for: .valueChanged)
    }

    @objc
    private func sourceSwitchValueChanged(_: Any) {
        if sourceSwitch.isOn {
            featureToggleService.source = .local
        } else {
            featureToggleService.source = .remote
        }
        tableView.reloadData()
    }

    private func layoutViews() {
        let sourceLabel = sourceLabel
        headerView.translatesAutoresizingMaskIntoConstraints = false
        sourceSwitch.translatesAutoresizingMaskIntoConstraints = false
        sourceLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            headerView.trailingAnchor.constraint(equalTo: sourceSwitch.trailingAnchor, constant: 8),
            sourceSwitch.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 8),
            headerView.bottomAnchor.constraint(equalTo: sourceSwitch.bottomAnchor, constant: 8),
            sourceSwitch.leadingAnchor.constraint(equalTo: sourceLabel.trailingAnchor, constant: 8),
            sourceLabel.centerYAnchor.constraint(equalTo: sourceSwitch.centerYAnchor),
            sourceLabel.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 8),
            tableView.widthAnchor.constraint(equalTo: headerView.widthAnchor),
        ])

        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        var frame = headerView.frame
        frame.size.height = height
        headerView.frame = frame
        tableView.tableHeaderView = headerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        layoutViews()
        sourceSwitch.isOn = featureToggleService.source == .local
    }
}

// MARK: - UITableViewDelegate

extension FeatureTogglesViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard sourceSwitch.isOn else { return }
        let feature = features[indexPath.row]
        if featureToggleService.isEnabled(feature) {
            featureToggleService.disableLocal(feature)
        } else {
            featureToggleService.enableLocal(feature)
        }
        self.tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource

extension FeatureTogglesViewController {
    override func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        features.count
    }

    override func tableView(_: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: Self.featureCellReuseIdentifier)
        cell.backgroundColor = .clear
        let feature = features[indexPath.row]
        cell.textLabel?.text = Self.title(for: feature)
        cell.textLabel?.font = UIFont.Muli(.bold, size: 16)
        cell.textLabel?.textColor = RuuviColor.menuTextColor.color
        if featureToggleService.isEnabled(feature) {
            cell.accessoryType = .checkmark
            cell.tintColor = RuuviColor.tintColor.color
        } else {
            cell.accessoryType = .none
        }
        return cell
    }
}

// MARK: - Helpers

extension FeatureTogglesViewController {
    private static func title(for feature: Feature) -> String {
        switch feature {
        case .legacyFirmwareUpdatePopup:
            "Legacy Firmware Update Alert"
        }
    }
}

// MARK: - Factory

extension FeatureTogglesViewController {
    private static func makeSourceLabel() -> UILabel {
        let label = UILabel()
        label.text = "Use local feature toggles"
        label.textAlignment = .right
        label.font = UIFont.Muli(.bold, size: 16)
        label.textColor = RuuviColor.menuTextColor.color
        return label
    }
}
