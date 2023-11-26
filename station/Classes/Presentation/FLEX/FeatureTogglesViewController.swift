import UIKit

final class FeatureTogglesViewController: UITableViewController {
    var featureToggleService: FeatureToggleService!

    init() {
        self.headerView = UIView()
        self.sourceSwitch = RuuviUISwitch()
        self.sourceLabel = Self.makeSourceLabel()
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let headerView: UIView
    private let sourceSwitch: RuuviUISwitch
    private let sourceLabel: UILabel
    private let features = Feature.allCases
    private static let featureCellReuseIdentifier = "FeatureCellReuseIdentifier"

    private func setupViews() {
        self.view.backgroundColor = RuuviColor.ruuviPrimary
        self.headerView.addSubview(self.sourceSwitch)
        self.headerView.addSubview(self.sourceLabel)
        self.tableView.tableHeaderView = self.headerView
        self.sourceSwitch.addTarget(self, action: #selector(sourceSwitchValueChanged(_:)), for: .valueChanged)
    }

    @objc
    private func sourceSwitchValueChanged(_ sender: Any) {
        if self.sourceSwitch.isOn {
            self.featureToggleService.source = .local
        } else {
            self.featureToggleService.source = .remote
        }
        self.tableView.reloadData()
    }

    private func layoutViews() {
        let headerView = self.headerView

        let sourceSwitch = self.sourceSwitch
        sourceSwitch.onTintColor = .clear
        sourceSwitch.thumbTintColor = RuuviColor.ruuviTintColor

        let sourceLabel = self.sourceLabel
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
            self.tableView.widthAnchor.constraint(equalTo: headerView.widthAnchor)
        ])

        headerView.setNeedsLayout()
        headerView.layoutIfNeeded()
        let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
        var frame = headerView.frame
        frame.size.height = height
        headerView.frame = frame
        self.tableView.tableHeaderView = headerView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupViews()
        self.layoutViews()
        self.sourceSwitch.isOn = self.featureToggleService.source == .local
    }
}

// MARK: - UITableViewDelegate
extension FeatureTogglesViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard self.sourceSwitch.isOn else { return }
        let feature = self.features[indexPath.row]
        if self.featureToggleService.isEnabled(feature) {
            self.featureToggleService.disableLocal(feature)
        } else {
            self.featureToggleService.enableLocal(feature)
        }
        self.tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension FeatureTogglesViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.features.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: Self.featureCellReuseIdentifier)
        cell.backgroundColor = .clear
        let feature = self.features[indexPath.row]
        cell.textLabel?.text = Self.title(for: feature)
        cell.textLabel?.font = UIFont.Muli(.bold, size: 16)
        cell.textLabel?.textColor = RuuviColor.ruuviMenuTextColor
        if self.featureToggleService.isEnabled(feature) {
            cell.accessoryType = .checkmark
            cell.tintColor = RuuviColor.ruuviTintColor
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
            return "Legacy Firmware Update Alert"
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
        label.textColor = RuuviColor.ruuviMenuTextColor
        return label
    }
}
