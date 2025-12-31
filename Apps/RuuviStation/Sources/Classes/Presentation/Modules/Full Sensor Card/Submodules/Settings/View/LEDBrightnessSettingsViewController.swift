import UIKit
import RuuviCore
import RuuviLocalization
import RuuviOntology

final class LEDBrightnessSettingsViewController: UIViewController {
    var onSelection: ((RuuviLedBrightnessLevel, @escaping (Result<Void, Error>) -> Void) -> Void)?
    var onUpdateFirmware: (() -> Void)?

    private let options = RuuviLedBrightnessLevel.allCases
    private let reuseIdentifier = "LEDBrightnessSettingsCell"
    private let snapshotId: String?
    private var firmwareVersion: String?
    private var selection: RuuviLedBrightnessLevel? {
        didSet {
            if isViewLoaded {
                tableView.reloadData()
            }
        }
    }
    private var isApplyingSelection = false
    private var isFirmwareSupported: Bool {
        guard let firmwareVersion,
              let firmwareSemVer = firmwareVersion.semVar else {
            return false
        }
        return Array.compareVersions(firmwareSemVer, [1, 3, 0]) != .orderedAscending
    }

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.sectionFooterHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.register(
            ASSelectionTableViewCell.self,
            forCellReuseIdentifier: reuseIdentifier
        )
        return tableView
    }()

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

    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = RuuviColor.textColor.color
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.ruuviBody()
        return label
    }()

    private lazy var updateButton: UIButton = {
        let button = UIButton(
            color: RuuviColor.tintColor.color,
            cornerRadius: 25
        )
        button.setTitle(RuuviLocalization.updateNow, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = UIFont.ruuviButtonMedium()
        button.addTarget(self, action: #selector(updateButtonDidTap), for: .touchUpInside)
        button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        return button
    }()

    private lazy var headerStackView: UIStackView = {
        let stackView = UIStackView(arrangedSubviews: [messageLabel, updateButton])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.alignment = .fill
        stackView.distribution = .fill
        stackView.isLayoutMarginsRelativeArrangement = true
        stackView.layoutMargins = .init(top: 16, left: 20, bottom: 16, right: 20)
        return stackView
    }()

    init(
        selection: RuuviLedBrightnessLevel? = nil,
        firmwareVersion: String?,
        snapshotId: String?
    ) {
        self.selection = selection
        self.firmwareVersion = firmwareVersion
        self.snapshotId = snapshotId
        super.init(nibName: nil, bundle: nil)
        title = RuuviLocalization.ledBrightnessControl
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        RuuviTagServiceCoordinatorManager.shared.addObserver(self)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        RuuviTagServiceCoordinatorManager.shared.removeObserver(self)
    }

    deinit {
        RuuviTagServiceCoordinatorManager.shared.removeObserver(self)
    }
}

private extension LEDBrightnessSettingsViewController {
    func setUpUI() {
        view.backgroundColor = RuuviColor.primary.color

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

        view.addSubview(headerStackView)
        headerStackView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )

        view.addSubview(tableView)
        tableView.anchor(
            top: headerStackView.bottomAnchor,
            leading: view.leadingAnchor,
            bottom: view.safeBottomAnchor,
            trailing: view.trailingAnchor
        )

        applyFirmwareState()
    }

    func applyFirmwareState() {
        messageLabel.text = isFirmwareSupported
            ? RuuviLocalization.ledBrightnessSelectMessage
            : RuuviLocalization.ledBrightnessFwUpdateMessage
        updateButton.isHidden = isFirmwareSupported
        tableView.isHidden = !isFirmwareSupported
    }

    func updateFirmwareVersionIfNeeded(_ version: String?) {
        guard firmwareVersion != version else { return }
        firmwareVersion = version
        applyFirmwareState()
        tableView.reloadData()
    }

    @objc func backButtonDidTap() {
        _ = navigationController?.popViewController(animated: true)
    }

    @objc func updateButtonDidTap() {
        onUpdateFirmware?()
    }
}

// MARK: - UITableViewDataSource
extension LEDBrightnessSettingsViewController: UITableViewDataSource {
    func tableView(
        _ tableView: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        isFirmwareSupported ? options.count : 0
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: reuseIdentifier,
            for: indexPath
        ) as? ASSelectionTableViewCell else {
            return UITableViewCell()
        }
        let option = options[indexPath.row]
        cell.configure(title: option.title, selection: selection?.title)
        return cell
    }
}

// MARK: - UITableViewDelegate
extension LEDBrightnessSettingsViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard isFirmwareSupported else { return }
        guard let onSelection, !isApplyingSelection else { return }
        let option = options[indexPath.row]
        selection = option
        isApplyingSelection = true
        onSelection(option) { [weak self] _ in
            self?.isApplyingSelection = false
        }
    }
}

// MARK: - RuuviTagServiceCoordinatorObserver
extension LEDBrightnessSettingsViewController: RuuviTagServiceCoordinatorObserver {
    func coordinatorDidReceiveEvent(
        _ coordinator: RuuviTagServiceCoordinator,
        event: RuuviTagServiceCoordinatorEvent
    ) {
        switch event {
        case let .snapshotUpdated(snapshot, _),
             let .alertSnapshotUpdated(snapshot),
             let .connectionSnapshotUpdated(snapshot):
            guard snapshot.id == snapshotId else { return }
            updateFirmwareVersionIfNeeded(snapshot.displayData.firmwareVersion)
        case let .snapshotsUpdated(snapshots, _, _):
            guard let snapshotId else { return }
            guard let snapshot = snapshots.first(where: { $0.id == snapshotId }) else { return }
            updateFirmwareVersionIfNeeded(snapshot.displayData.firmwareVersion)
        default:
            break
        }
    }
}
