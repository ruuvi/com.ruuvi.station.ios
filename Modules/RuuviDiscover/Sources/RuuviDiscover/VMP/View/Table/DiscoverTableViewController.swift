// swiftlint:disable file_length
import BTKit
import CoreNFC
import RuuviLocalization
import RuuviOntology
import UIKit

enum DiscoverTableSection {
    case device
    case noDevices

    static var count = 1

    static func section(for deviceCount: Int) -> DiscoverTableSection {
        deviceCount > 0 ? .device : .noDevices
    }
}

class DiscoverTableViewController: UIViewController {
    var output: DiscoverViewOutput!

    // MARK: - UI Components

    private lazy var headerView: DiscoverHeaderView = {
        let headerView = DiscoverHeaderView()
        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.delegate = self
        headerView.handleNFCButtonViewVisibility(
            show: isBluetoothEnabled
        )
        return headerView
    }()

    /// The table's header: `headerView` plus today's 8 pt gap above the list. Being the table
    /// header, the description scrolls with the list instead of taking a fixed part of short
    /// windows. Sized in `viewDidLayoutSubviews`.
    private lazy var tableHeaderContainer: UIView = {
        let container = UIView()
        container.backgroundColor = .clear
        container.addSubview(headerView)
        let bottom = headerView.bottomAnchor.constraint(
            equalTo: container.bottomAnchor,
            constant: -8
        )
        // Breakable, so the container's frame never conflicts with it before it is sized.
        bottom.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: container.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            bottom,
        ])
        return container
    }()

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.rowHeight = DiscoverTableViewController.rowHeight
        // Sensor rows are exactly this high (see `heightForRowAt`), so estimates are exact too.
        tableView.estimatedRowHeight = DiscoverTableViewController.rowHeight
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        // The header is `tableHeaderContainer` (set in `setupViews`).
        let footerView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 0,
                height: CGFloat.leastNormalMagnitude
            )
        )
        tableView.tableFooterView = footerView
        return tableView
    }()

    /// Measures the "no sensors" row, whose text can need more lines than 44 pt hold.
    private lazy var noDevicesSizingCell = DiscoverNoDevicesTableViewCell(
        style: .default,
        reuseIdentifier: nil
    )
    /// The last measured "no sensors" row height, for the table width and text it was measured at.
    private var noDevicesRowHeightCache: MeasuredRowHeight?
    /// The "no sensors" row height last handed to the table.
    private var appliedNoDevicesRowHeight: CGFloat?

    private lazy var closeBarButtonItem: UIBarButtonItem = {
        let button = UIBarButtonItem(
            image: RuuviAsset.dismissModalIcon.image,
            style: .plain,
            target: self,
            action: #selector(closeBarButtonItemAction)
        )
        button.tintColor = .label
        return button
    }()

    private lazy var actionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = RuuviColor.tintColor.color
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(
            top: 12,
            leading: 8,
            bottom: 12,
            trailing: 8
        )
        config.cornerStyle = .fixed
        config.background.cornerRadius = 22

        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(
            self,
            action: #selector(handleActionButtonTap),
            for: .touchUpInside
        )
        return button
    }()

    private var alertVC: UIAlertController?

    var ruuviTags: [DiscoverRuuviTagViewModel] = .init() {
        didSet {
            updateTableView()
        }
    }

    var isBluetoothEnabled: Bool = true {
        didSet {
            updateTableView()
        }
    }

    var isCloseEnabled: Bool = true {
        didSet {
            updateUIIsCloseEnabled()
        }
    }

    private let hideAlreadyAddedWebProviders = false
    private var session: NFCNDEFReaderSession?

    /// Today's row height. Sensor rows always use it; the "no sensors" row only grows past it.
    private static let rowHeight: CGFloat = 44

    private struct MeasuredRowHeight {
        let width: CGFloat
        let text: String
        let height: CGFloat
    }
}

// MARK: - DiscoverViewInput

extension DiscoverTableViewController: DiscoverViewInput {
    func style() {
        view.backgroundColor = RuuviColor.primary.color
    }

    func localize() {
        navigationItem.title = RuuviLocalization
            .DiscoverTable.NavigationItem.title
        actionButton.setTitle(
            RuuviLocalization.DiscoverTable.GetMoreSensors
                .Button.title.capitalized,
            for: .normal
        )
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        // The simulator has no Bluetooth: don't show this alert there.
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        guard !isSimulator else { return }
        let title = RuuviLocalization.DiscoverTable
            .BluetoothDisabledAlert.title
        let message = RuuviLocalization.DiscoverTable
            .BluetoothDisabledAlert.message
        let alertVC = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alertVC.addAction(
            UIAlertAction(
                title: RuuviLocalization.PermissionPresenter.settings,
                style: .default,
                handler: { [weak self] _ in
                    self?.takeUserToBTSettings(
                        userDeclined: userDeclined
                    )
                }
            )
        )
        alertVC.addAction(
            UIAlertAction(
                title: RuuviLocalization.ok,
                style: .cancel,
                handler: nil
            )
        )
        present(alertVC, animated: true)
    }

    func startNFCSession() {
        session?.invalidate()
        session = nil

        session = NFCNDEFReaderSession(
            delegate: self,
            queue: nil,
            invalidateAfterFirstRead: false
        )
        session?.begin()
    }

    func stopNFCSession() {
        session?.invalidate()
        session = nil
    }

    func showUpdateFirmwareDialog(for uuid: String) {
        let title = RuuviLocalization.DiscoverTable
            .UpdateFirmware.title
        let message = RuuviLocalization.DiscoverTable
            .UpdateFirmware.message
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        let cancelTitle = RuuviLocalization.cancel
        alert.addAction(
            UIAlertAction(
                title: cancelTitle,
                style: .cancel,
                handler: nil
            )
        )
        alert.addAction(
            UIAlertAction(
                title: title,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidConfirmToUpdateFirmware(
                        for: uuid
                    )
                }
            )
        )
        present(alert, animated: true)
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    func showSensorDetailsDialog(
        for tag: NFCSensor?,
        message: String,
        showAddSensor: Bool,
        showGoToSensor: Bool,
        showUpgradeFirmware: Bool,
        isDF3: Bool
    ) {
        let title = RuuviLocalization.sensorDetails

        var messageString = message
        if isDF3 {
            let df3ErrorMessage = RuuviLocalization
                .addSensorNfcDf3Error
            messageString = "\n\(df3ErrorMessage)\n" + message
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let messageText = NSAttributedString(
            string: messageString,
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.foregroundColor: UIColor.label,
                NSAttributedString.Key.font: UIFont.preferredFont(
                    forTextStyle: .body
                ),
            ]
        )

        let alertVC = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .alert
        )
        alertVC.setValue(messageText, forKey: "attributedMessage")

        if showAddSensor {
            alertVC.addAction(
                UIAlertAction(
                    title: RuuviLocalization.addSensor,
                    style: .default,
                    handler: { [weak self] _ in
                        self?.output.viewDidAddDeviceWithNFC(with: tag)
                    }
                )
            )
        }

        alertVC.addAction(
            UIAlertAction(
                title: RuuviLocalization.copyMacAddress,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidACopyMacAddress(of: tag)
                }
            )
        )

        alertVC.addAction(
            UIAlertAction(
                title: RuuviLocalization.copyUniqueId,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidACopySecret(of: tag)
                }
            )
        )

        if showGoToSensor {
            alertVC.addAction(
                UIAlertAction(
                    title: RuuviLocalization.goToSensor,
                    style: .default,
                    handler: { [weak self] _ in
                        self?.output.viewDidGoToSensor(with: tag)
                    }
                )
            )
        }

        if showUpgradeFirmware {
            alertVC.addAction(
                UIAlertAction(
                    title: RuuviLocalization.DFUUIView
                        .navigationTitle,
                    style: .default,
                    handler: { [weak self] _ in
                        self?.output.viewDidAskToUpgradeFirmware(
                            of: tag
                        )
                    }
                )
            )
        }

        alertVC.addAction(
            UIAlertAction(
                title: RuuviLocalization.close,
                style: .cancel,
                handler: nil
            )
        )
        present(alertVC, animated: true)
    }
}

// MARK: - Actions

extension DiscoverTableViewController {
    @objc private func closeBarButtonItemAction() {
        output.viewDidTriggerClose()
    }

    @objc private func handleActionButtonTap() {
        output.viewDidTriggerBuySensors()
    }
}

// MARK: - DiscoverHeaderViewDelegate

extension DiscoverTableViewController: DiscoverHeaderViewDelegate {
    func didTapAddWithNFCButton(sender _: DiscoverHeaderView) {
        output.viewDidTapUseNFC()
    }
}

// MARK: - View lifecycle

extension DiscoverTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        localize()
        style()
        configureViews()
        updateUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.setHidesBackButton(true, animated: animated)
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateTableHeaderSize()
        updateNoDevicesRowHeightIfNeeded()
    }
}

// MARK: - UITableViewDataSource

extension DiscoverTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        DiscoverTableSection.count
    }

    func tableView(
        _: UITableView,
        numberOfRowsInSection _: Int
    ) -> Int {
        let section = DiscoverTableSection.section(
            for: ruuviTags.count
        )
        switch section {
        case .device:
            return ruuviTags.count
        case .noDevices:
            return 1
        }
    }

    func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let section = DiscoverTableSection.section(
            for: ruuviTags.count
        )
        switch section {
        case .device:
            let cell = tableView.dequeueReusableCell(
                with: DiscoverDeviceTableViewCell.self,
                for: indexPath
            )
            let tag = ruuviTags[indexPath.row]
            configure(cell: cell, with: tag)
            return cell
        case .noDevices:
            let cell = tableView.dequeueReusableCell(
                with: DiscoverNoDevicesTableViewCell.self,
                for: indexPath
            )
            cell.descriptionLabel.text = noDevicesText
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DiscoverTableViewController: UITableViewDelegate {
    func tableView(
        _ tableView: UITableView,
        heightForRowAt _: IndexPath
    ) -> CGFloat {
        switch DiscoverTableSection.section(for: ruuviTags.count) {
        case .device:
            return Self.rowHeight
        case .noDevices:
            let height = noDevicesRowHeight(for: tableView.bounds.width)
            appliedNoDevicesRowHeight = height
            return height
        }
    }

    func tableView(
        _ tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sectionType = DiscoverTableSection.section(
            for: ruuviTags.count
        )
        switch sectionType {
        case .device:
            if indexPath.row < ruuviTags.count {
                let device = ruuviTags[indexPath.row]
                output.viewDidChoose(
                    device: device,
                    displayName: displayName(for: device)
                )
            }
        case .noDevices:
            if !isBluetoothEnabled {
                output.viewDidTriggerDisabledBTRow()
            }
        }
    }
}

// MARK: - Cell configuration

extension DiscoverTableViewController {
    private func configure(
        cell: DiscoverDeviceTableViewCell,
        with device: DiscoverRuuviTagViewModel
    ) {
        cell.identifierLabel.text = displayName(for: device)

        if let rssi = device.rssi {
            cell.rssiLabel.text = "\(rssi) \(RuuviLocalization.dBm)"

            let image: UIImage?
            if rssi < -80 {
                image = RuuviAsset.iconConnection1.image
            } else if rssi < -50 {
                image = RuuviAsset.iconConnection2.image
            } else {
                image = RuuviAsset.iconConnection3.image
            }

            cell.rssiImageView.image = image?
                .withRenderingMode(.alwaysTemplate)
            cell.rssiImageView.tintColor = RuuviColor.tintColor.color
        } else {
            cell.rssiImageView.image = nil
            cell.rssiLabel.text = nil
        }
    }
}

// MARK: - Setup Views

extension DiscoverTableViewController {
    private func setupViews() {
        view.backgroundColor = RuuviColor.primary.color

        // The button goes first: UIKit follows the root view's first-subview chain to find the scroll
        // view that drives the navigation bar's scroll-edge appearance. With the table first, the bar
        // would switch to its default background and hairline while the list is scrolled; with no
        // scroll view found it stays transparent, as before. The two views don't overlap.
        view.addSubview(actionButton)
        view.addSubview(tableView)
        // The header is the table's header, so it scrolls with the list. The table starts where
        // the header used to and has the same width, so the screen looks the same at rest.
        tableView.tableHeaderView = tableHeaderContainer

        // 210 pt, but never wider than the safe area minus 16 pt on each side.
        let actionButtonWidth = actionButton.widthAnchor.constraint(equalToConstant: 210)
        actionButtonWidth.priority = UILayoutPriority(999)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            tableView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor
            ),
            tableView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor
            ),
            tableView.bottomAnchor.constraint(
                equalTo: actionButton.topAnchor,
                constant: -24
            ),

            // Centred on the content (the safe area), which has the same centre as the view
            // unless the side insets differ (iPhone Duo vertical bar, iPad window insets).
            actionButton.centerXAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.centerXAnchor
            ),
            actionButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -24
            ),
            actionButtonWidth,
            actionButton.widthAnchor.constraint(
                lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor,
                constant: -32
            ),
            actionButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        tableView.register(
            DiscoverDeviceTableViewCell.self,
            forCellReuseIdentifier: String(
                describing: DiscoverDeviceTableViewCell.self
            )
        )
        tableView.register(
            DiscoverNoDevicesTableViewCell.self,
            forCellReuseIdentifier: String(
                describing: DiscoverNoDevicesTableViewCell.self
            )
        )
    }

    private func configureViews() {
        navigationController?.navigationBar.titleTextAttributes = [
            .font: UIFont.ruuviButtonLarge()
        ]
    }
}

// MARK: - Update UI

extension DiscoverTableViewController {
    private func updateUI() {
        updateTableView()
        updateUIIsCloseEnabled()
    }

    private func updateUIIsCloseEnabled() {
        if isViewLoaded {
            if isCloseEnabled {
                navigationItem.leftBarButtonItem = closeBarButtonItem
            } else {
                navigationItem.leftBarButtonItem = nil
            }
        }
    }

    private func updateTableView() {
        if isViewLoaded {
            tableView.reloadData()
        }
    }

    private var noDevicesText: String {
        isBluetoothEnabled
            ? RuuviLocalization.DiscoverTable
                .NoDevicesSection.NotFound.text
            : RuuviLocalization.DiscoverTable
                .NoDevicesSection.BluetoothDisabled.text
    }

    /// Sizes the table header to its content at the table's current width. Runs on every layout
    /// pass, so it follows window resizes, and re-assigns the header only when its size changed
    /// (that is what makes the table move its rows).
    private func updateTableHeaderSize() {
        let width = tableView.bounds.width
        guard width > 0 else { return }
        let container = tableHeaderContainer
        if container.frame.width != width {
            // Lets the multi-line description wrap at the new width before it is measured.
            container.frame.size.width = width
            container.layoutIfNeeded()
        }
        let height = container.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        guard container.frame.width != width || container.frame.height != height else { return }
        container.frame = CGRect(x: 0, y: 0, width: width, height: height)
        tableView.tableHeaderView = container
    }

    /// The "no sensors" row: today's 44 pt, taller only when its text needs more lines (long
    /// translations, narrow windows), so the text is never clipped.
    private func noDevicesRowHeight(for width: CGFloat) -> CGFloat {
        guard width > 0 else { return Self.rowHeight }
        let text = noDevicesText
        if let cache = noDevicesRowHeightCache, cache.width == width, cache.text == text {
            return cache.height
        }
        let cell = noDevicesSizingCell
        cell.descriptionLabel.text = text
        cell.bounds = CGRect(x: 0, y: 0, width: width, height: Self.rowHeight)
        cell.layoutIfNeeded()
        let contentHeight = cell.contentView.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        ).height
        // + 1 pt leaves room for the cell separator below the content view.
        let height = max(Self.rowHeight, ceil(contentHeight) + 1)
        noDevicesRowHeightCache = MeasuredRowHeight(width: width, text: text, height: height)
        return height
    }

    /// A width change alone isn't guaranteed to make the table ask for row heights again, so reload
    /// the single "no sensors" row when its height at the new width differs from the one it has.
    private func updateNoDevicesRowHeightIfNeeded() {
        guard DiscoverTableSection.section(for: ruuviTags.count) == .noDevices,
              let appliedNoDevicesRowHeight,
              noDevicesRowHeight(for: tableView.bounds.width) != appliedNoDevicesRowHeight
        else {
            return
        }
        tableView.reloadData()
    }

    private func displayName(
        for device: DiscoverRuuviTagViewModel
    ) -> String {
        Helpers
            .ruuviDeviceDefaultName(
                from: device.mac,
                luid: device.luid?.value,
                dataFormat: device.dataFormat
            )
    }

    private func takeUserToBTSettings(userDeclined: Bool) {
        guard let url = URL(
            string: userDeclined
                ? UIApplication.openSettingsURLString
                : "App-prefs:Bluetooth"
        ),
            UIApplication.shared.canOpenURL(url)
        else {
            return
        }
        UIApplication.shared.open(url)
    }
}

// MARK: - NFCNDEFReaderSessionDelegate

extension DiscoverTableViewController: NFCNDEFReaderSessionDelegate {
    func readerSession(
        _: NFCNDEFReaderSession,
        didInvalidateWithError _: Error
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.stopNFCSession()
        }
    }

    func readerSession(
        _: NFCNDEFReaderSession,
        didDetectNDEFs messages: [NFCNDEFMessage]
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.viewDidReceiveNFCMessages(messages: messages)
        }
    }
}

// swiftlint:enable file_length
