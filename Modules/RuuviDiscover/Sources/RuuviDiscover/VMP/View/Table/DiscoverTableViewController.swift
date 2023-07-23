import UIKit
import BTKit
import RuuviOntology
import RuuviVirtual
import RuuviLocalization
import RuuviBundleUtils
import CoreNFC

enum DiscoverTableSection {
    case device
    case noDevices

    static var count = 1 // displayed simultaneously

    static func section(for deviceCount: Int) -> DiscoverTableSection {
        return deviceCount > 0 ? .device : .noDevices
    }
}

class DiscoverTableViewController: UIViewController {

    var output: DiscoverViewOutput!

    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var actionButton: UIButton!
    private var discoverTableHeaderView = DiscoverTableHeaderView()

    private var alertVC: UIAlertController?

    var ruuviTags: [DiscoverRuuviTagViewModel] = [DiscoverRuuviTagViewModel]() {
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
        navigationItem.title = "DiscoverTable.NavigationItem.title".localized(for: Self.self)
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = "DiscoverTable.BluetoothDisabledAlert.title".localized(for: Self.self)
        let message = "DiscoverTable.BluetoothDisabledAlert.message".localized(for: Self.self)
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "PermissionPresenter.settings".localized(for: Self.self),
                                        style: .default, handler: { [weak self] _ in
            self?.takeUserToBTSettings(userDeclined: userDeclined)
        }))
        alertVC.addAction(UIAlertAction(title: "OK".localized(for: Self.self), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showWebTagInfoDialog() {
        let message = "DiscoverTable.WebTagsInfoDialog.message".localized(for: Self.self)
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(for: Self.self), style: .cancel, handler: nil))
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

    func showSensorDetailsDialog(
        for tag: NFCSensor?,
        message: String,
        showAddSensor: Bool,
        isDF3: Bool
    ) {
        let title = "sensor_details".localized(for: Self.self)

        // Message
        var messageString = message
        // We show extra message for DF3 sensors since they can't be added with NFC.
        if isDF3 {
            let df3ErrorMessage = "add_sensor_nfc_df3_error".localized(
                for: Self.self
              )
            messageString = "\n\(df3ErrorMessage)\n" + message
        }

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .left
        let messageText = NSAttributedString(
            string: messageString,
            attributes: [
                NSAttributedString.Key.paragraphStyle: paragraphStyle,
                NSAttributedString.Key.foregroundColor: UIColor.label,
                NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .body)
            ]
        )

        let alertVC = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        alertVC.setValue(messageText, forKey: "attributedMessage")

        if showAddSensor {
          alertVC.addAction(UIAlertAction(title: "add_sensor".localized(for: Self.self),
                                          style: .default, handler: { [weak self] _ in
            self?.output.viewDidAddDeviceWithNFC(with: tag)
          }))
        }

        alertVC.addAction(UIAlertAction(title: "copy_details".localized(for: Self.self),
                                        style: .default, handler: { [weak self] _ in
            self?.output.viewDidACopySensorDetails(with: message)
        }))

        alertVC.addAction(UIAlertAction(title: "close".localized(for: Self.self), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

// MARK: - IBActions
extension DiscoverTableViewController {
    @IBAction func closeBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerClose()
    }

    @IBAction func handleActionButtonTap(_ sender: Any) {
        output.viewDidTriggerBuySensors()
    }
}

// MARK: - DiscoverTableHeaderViewDelegate
extension DiscoverTableViewController: DiscoverTableHeaderViewDelegate {
    func didTapAddWithNFCButton(sender: DiscoverTableHeaderView) {
        output.viewDidTapUseNFC()
    }
}

// MARK: - View lifecycle
extension DiscoverTableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocalization()
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
    func numberOfSections(in tableView: UITableView) -> Int {
        return DiscoverTableSection.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
                ? "DiscoverTable.NoDevicesSection.NotFound.text".localized(for: Self.self)
                : "DiscoverTable.NoDevicesSection.BluetoothDisabled.text".localized(for: Self.self)
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
            cell.rssiLabel.text = "\(rssi)" + " " + "dBm".localized(for: Self.self)
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
        actionButton.setTitle("DiscoverTable.GetMoreSensors.button.title".localized(
            for: Self.self
        ).capitalized, for: .normal)
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
                show: ruuviTags.count > 0
            )
            tableView.reloadData()
        }
    }

    private func displayName(for device: DiscoverRuuviTagViewModel) -> String {
        // identifier
        if let mac = device.mac {
            return "DiscoverTable.RuuviDevice.prefix".localized(for: Self.self)
                + " " + mac.replacingOccurrences(of: ":", with: "").suffix(4)
        } else {
            return "DiscoverTable.RuuviDevice.prefix".localized(for: Self.self)
                + " " + (device.luid?.value.prefix(4) ?? "")
        }
    }

    private func takeUserToBTSettings(userDeclined: Bool) {
        guard let url = URL(string: userDeclined ?
                            UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
              UIApplication.shared.canOpenURL(url) else {
            return
        }
        UIApplication.shared.open(url)
    }
}

// MARK: - NFCNDEFReaderSessionDelegate
extension DiscoverTableViewController: NFCNDEFReaderSessionDelegate {
    func readerSession(_ session: NFCNDEFReaderSession,
                       didInvalidateWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.stopNFCSession()
        }
    }

    func readerSession(_ session: NFCNDEFReaderSession,
                       didDetectNDEFs messages: [NFCNDEFMessage]) {
        DispatchQueue.main.async { [weak self] in
            self?.output?.viewDidReceiveNFCMessages(messages: messages)
        }
    }
}
