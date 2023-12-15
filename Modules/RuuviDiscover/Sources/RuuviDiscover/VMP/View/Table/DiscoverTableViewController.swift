// swiftlint:disable file_length
import BTKit
import CoreNFC
import RuuviLocalization
import RuuviOntology
import UIKit

enum DiscoverTableSection {
    case device
    case noDevices

    static var count = 1 // displayed simultaneously

    static func section(for deviceCount: Int) -> DiscoverTableSection {
        deviceCount > 0 ? .device : .noDevices
    }
}

class DiscoverTableViewController: UIViewController {
    var output: DiscoverViewOutput!

    @IBOutlet var tableView: UITableView!
    @IBOutlet var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet var actionButton: UIButton!
    private var discoverTableHeaderView = DiscoverTableHeaderView()

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
    func localize() {
        navigationItem.title = RuuviLocalization.DiscoverTable.NavigationItem.title
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.title
        let message = RuuviLocalization.DiscoverTable.BluetoothDisabledAlert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(
            UIAlertAction(
                title: RuuviLocalization.PermissionPresenter.settings,
                style: .default,
                handler: { [weak self] _ in
                    self?.takeUserToBTSettings(userDeclined: userDeclined)
                }
            )
        )
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
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

        // Message
        var messageString = message
        // We show extra message for DF3 sensors since they can't be added with NFC.
        if isDF3 {
            let df3ErrorMessage = RuuviLocalization.addSensorNfcDf3Error
            messageString = "\n\(df3ErrorMessage)\n" + message
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let messageText = NSAttributedString(
            string: messageString,
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.foregroundColor: UIColor.label,
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body),
            ]
        )

        let alertVC = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alertVC.setValue(messageText, forKey: "attributedMessage")

        if showAddSensor {
            alertVC.addAction(UIAlertAction(
                title: RuuviLocalization.addSensor,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidAddDeviceWithNFC(with: tag)
                }
            ))
        }

        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.copyMacAddress,
            style: .default,
            handler: { [weak self] _ in
                self?.output.viewDidACopyMacAddress(of: tag)
            }
        ))

        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.copyUniqueId,
            style: .default,
            handler: { [weak self] _ in
                self?.output.viewDidACopySecret(of: tag)
            }
        ))

        if showGoToSensor {
            alertVC.addAction(UIAlertAction(
                title: RuuviLocalization.goToSensor,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidGoToSensor(with: tag)
                }
            ))
        }

        if showUpgradeFirmware {
            alertVC.addAction(UIAlertAction(
                title: RuuviLocalization.DFUUIView.navigationTitle,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidAskToUpgradeFirmware(of: tag)
                }
            ))
        }

        alertVC.addAction(UIAlertAction(title: RuuviLocalization.close, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

// MARK: - IBActions

extension DiscoverTableViewController {
    @IBAction func closeBarButtonItemAction(_: Any) {
        output.viewDidTriggerClose()
    }

    @IBAction func handleActionButtonTap(_: Any) {
        output.viewDidTriggerBuySensors()
    }
}

// MARK: - DiscoverTableHeaderViewDelegate

extension DiscoverTableViewController: DiscoverTableHeaderViewDelegate {
    func didTapAddWithNFCButton(sender _: DiscoverTableHeaderView) {
        output.viewDidTapUseNFC()
    }
}

// MARK: - View lifecycle

extension DiscoverTableViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        localize()
        configureViews()
        updateUI()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationItem.setHidesBackButton(true, animated: animated)
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let headerView = tableView.tableHeaderView {
            let height = headerView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height
            var headerFrame = headerView.frame

            if height != headerFrame.size.height {
                headerFrame.size.height = height
                headerView.frame = headerFrame
                tableView.tableHeaderView = headerView
            }
            headerView.translatesAutoresizingMaskIntoConstraints = true
        }
    }
}

// MARK: - UITableViewDataSource

extension DiscoverTableViewController: UITableViewDataSource {
    func numberOfSections(in _: UITableView) -> Int {
        DiscoverTableSection.count
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        let section = DiscoverTableSection.section(for: ruuviTags.count)
        switch section {
        case .device:
            return ruuviTags.count
        case .noDevices:
            return 1
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = DiscoverTableSection.section(for: ruuviTags.count)
        switch section {
        case .device:
            let cell = tableView.dequeueReusableCell(with: DiscoverDeviceTableViewCell.self, for: indexPath)
            let tag = ruuviTags[indexPath.row]
            configure(cell: cell, with: tag)
            return cell
        case .noDevices:
            let cell = tableView.dequeueReusableCell(with: DiscoverNoDevicesTableViewCell.self, for: indexPath)
            cell.descriptionLabel.text = isBluetoothEnabled
            ? RuuviLocalization.DiscoverTable.NoDevicesSection.NotFound.text
            : RuuviLocalization.DiscoverTable.NoDevicesSection.BluetoothDisabled.text
            return cell
        }
    }
}

// MARK: - UITableViewDelegate {

extension DiscoverTableViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sectionType = DiscoverTableSection.section(for: ruuviTags.count)
        switch sectionType {
        case .device:
            if indexPath.row < ruuviTags.count {
                let device = ruuviTags[indexPath.row]
                output.viewDidChoose(device: device, displayName: displayName(for: device))
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
    private func configure(cell: DiscoverDeviceTableViewCell, with device: DiscoverRuuviTagViewModel) {
        cell.identifierLabel.text = displayName(for: device)

        // RSSI
        if let rssi = device.rssi {
            cell.rssiLabel.text = "\(rssi)" + " " + RuuviLocalization.dBm
            if rssi < -80 {
                cell.rssiImageView.image = UIImage.named("icon-connection-1", for: Self.self)
            } else if rssi < -50 {
                cell.rssiImageView.image = UIImage.named("icon-connection-2", for: Self.self)
            } else {
                cell.rssiImageView.image = UIImage.named("icon-connection-3", for: Self.self)
            }
        } else {
            cell.rssiImageView.image = nil
            cell.rssiLabel.text = nil
        }
    }
}

// MARK: - View configuration

extension DiscoverTableViewController {
    private func configureViews() {
        if let muliBold = UIFont(name: "Muli-Bold", size: 18) {
            navigationController?.navigationBar.titleTextAttributes =
                [.font: muliBold]
        }
        actionButton.setTitle(RuuviLocalization.DiscoverTable.GetMoreSensors.Button.title.capitalized, for: .normal)
        configureTableView()
    }

    private func configureTableView() {
        tableView.rowHeight = 44
        tableView.delegate = self
        tableView.dataSource = self
        tableView.tableHeaderView = discoverTableHeaderView
        discoverTableHeaderView.delegate = self
        tableView.tableFooterView = UIView()
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
            discoverTableHeaderView.handleNFCButtonViewVisibility(
                show: isBluetoothEnabled
            )
            tableView.reloadData()
        }
    }

    private func displayName(for device: DiscoverRuuviTagViewModel) -> String {
        // identifier
        if let mac = device.mac {
            RuuviLocalization.DiscoverTable.RuuviDevice.prefix
                + " " + mac.replacingOccurrences(of: ":", with: "").suffix(4)
        } else {
            RuuviLocalization.DiscoverTable.RuuviDevice.prefix
                + " " + (device.luid?.value.prefix(4) ?? "")
        }
    }

    private func takeUserToBTSettings(userDeclined: Bool) {
        guard let url = URL(string: userDeclined ?
            UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
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
