import UIKit

final class FLEXFeatureTogglesViewController: UITableViewController {
    init() {
        self.headerView = UIView()
        self.sourceSwitch = UISwitch()
        self.sourceLabel = Self.makeSourceLabel()
        super.init(nibName: nil, bundle: nil)
        self.setupViews()
        self.layoutViews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let headerView: UIView
    private let sourceSwitch: UISwitch
    private let sourceLabel: UILabel

    private func setupViews() {
        self.headerView.addSubview(self.sourceSwitch)
        self.headerView.addSubview(self.sourceLabel)
        self.tableView.tableHeaderView = self.headerView
    }

    private func layoutViews() {
        let headerView = self.headerView
        let sourceSwitch = self.sourceSwitch
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
}

extension FLEXFeatureTogglesViewController {
    private static func makeSourceLabel() -> UILabel {
        let label = UILabel()
        label.text = "Use local feature toggles"
        label.textAlignment = .right
        return label
    }
}
