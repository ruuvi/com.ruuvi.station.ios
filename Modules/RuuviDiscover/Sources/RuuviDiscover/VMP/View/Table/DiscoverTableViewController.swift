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

    private lazy var tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .grouped)
        tableView.backgroundColor = .clear
        tableView.rowHeight = 44
        tableView.delegate = self
        tableView.dataSource = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        let headerFooterView = UIView(
            frame: CGRect(
                x: 0,
                y: 0,
                width: 0,
                height: CGFloat.leastNormalMagnitude
            )
        )
        tableView.tableHeaderView = headerFooterView
        tableView.tableFooterView = headerFooterView
        return tableView
    }()

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
            cell.descriptionLabel.text = isBluetoothEnabled
                ? RuuviLocalization.DiscoverTable
                    .NoDevicesSection.NotFound.text
                : RuuviLocalization.DiscoverTable
                    .NoDevicesSection.BluetoothDisabled.text
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension DiscoverTableViewController: UITableViewDelegate {
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

        view.addSubview(headerView)
        view.addSubview(tableView)
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor
            ),
            headerView.leadingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.leadingAnchor
            ),
            headerView.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor
            ),

            tableView.topAnchor.constraint(
                equalTo: headerView.bottomAnchor,
                constant: 8
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

            actionButton.centerXAnchor.constraint(
                equalTo: view.centerXAnchor
            ),
            actionButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -24
            ),
            actionButton.widthAnchor.constraint(equalToConstant: 210),
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
