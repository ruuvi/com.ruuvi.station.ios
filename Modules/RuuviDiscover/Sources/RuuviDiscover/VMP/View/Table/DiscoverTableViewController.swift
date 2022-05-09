import UIKit
import BTKit
import RuuviOntology
import RuuviVirtual
import RuuviLocalization
import RuuviBundleUtils

enum DiscoverTableSection {
    case webTag
    case device
    case noDevices

    static var count = 2 // displayed simultaneously

    static func section(for index: Int, deviceCount: Int) -> DiscoverTableSection {
        switch index {
        case 0:
            return .webTag
        default:
            return deviceCount > 0 ? .device : .noDevices
        }
    }
}

class DiscoverTableViewController: UITableViewController {

    var output: DiscoverViewOutput!

    @IBOutlet var closeBarButtonItem: UIBarButtonItem!
    @IBOutlet var btDisabledEmptyDataSetView: UIView!
    @IBOutlet weak var btDisabledImageView: UIImageView!
    @IBOutlet var getMoreSensorsEmptyDataSetView: UIView!
    @IBOutlet weak var getMoreSensorsEmptyDataSetButton: UIButton!

    private var alertVC: UIAlertController?

    var virtualTags: [DiscoverVirtualTagViewModel] = [DiscoverVirtualTagViewModel]()
    var savedWebTagProviders: [VirtualProvider] = [VirtualProvider]() {
        didSet {
            shownVirtualTags = virtualTags
                .filter({
                    if hideAlreadyAddedWebProviders {
                        return !savedWebTagProviders.contains($0.provider)
                    } else {
                        return true
                    }
                })
                .sorted(by: { $0.locationType.title < $1.locationType.title })
        }
    }

    var ruuviTags: [DiscoverRuuviTagViewModel] = [DiscoverRuuviTagViewModel]() {
        didSet {
            updateTableView()
        }
    }

    var isBluetoothEnabled: Bool = true {
        didSet {
            updateUIISBluetoothEnabled()
        }
    }

    var isCloseEnabled: Bool = true {
        didSet {
            updateUIIsCloseEnabled()
        }
    }

    private let hideAlreadyAddedWebProviders = false
    private var emptyDataSetView: UIView?
    private let webTagsInfoSectionHeaderReuseIdentifier = "DiscoverWebTagsInfoHeaderFooterView"
    private var shownVirtualTags: [DiscoverVirtualTagViewModel] = [DiscoverVirtualTagViewModel]() {
        didSet {
            updateTableView()
        }
    }
}

// MARK: - DiscoverViewInput
extension DiscoverTableViewController: DiscoverViewInput {

    func localize() {
        navigationItem.title = "DiscoverTable.NavigationItem.title".localized(for: Self.self)
        getMoreSensorsEmptyDataSetButton.setTitle(
            "DiscoverTable.GetMoreSensors.button.title".localized(for: Self.self),
            for: .normal
        )
    }

    func showBluetoothDisabled() {
        let title = "DiscoverTable.BluetoothDisabledAlert.title".localized(for: Self.self)
        let message = "DiscoverTable.BluetoothDisabledAlert.message".localized(for: Self.self)
        showAlert(title: title, message: message)
    }

    func showWebTagInfoDialog() {
        let message = "DiscoverTable.WebTagsInfoDialog.message".localized(for: Self.self)
        let alertVC = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(for: Self.self), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }
}

// MARK: - IBActions
extension DiscoverTableViewController {
    @IBAction func closeBarButtonItemAction(_ sender: Any) {
        output.viewDidTriggerClose()
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
        navigationController?.setNavigationBarHidden(false, animated: animated)
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        output.viewWillDisappear()
    }
}

// MARK: - UITableViewDataSource
extension DiscoverTableViewController {
    override func numberOfSections(in tableView: UITableView) -> Int {
        return DiscoverTableSection.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let section = DiscoverTableSection.section(for: section, deviceCount: ruuviTags.count)
        switch section {
        case .webTag:
            return shownVirtualTags.count
        case .device:
            return ruuviTags.count
        case .noDevices:
            return 1
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = DiscoverTableSection.section(for: indexPath.section, deviceCount: ruuviTags.count)
        switch section {
        case .webTag:
            let cell = tableView.dequeueReusableCell(with: DiscoverWebTagTableViewCell.self, for: indexPath)
            let tag = shownVirtualTags[indexPath.row]
            configure(cell: cell, with: tag)
            return cell
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
extension DiscoverTableViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let sectionType = DiscoverTableSection.section(for: indexPath.section, deviceCount: ruuviTags.count)
        switch sectionType {
        case .webTag:
            if indexPath.row < shownVirtualTags.count {
                output.viewDidChoose(webTag: shownVirtualTags[indexPath.row])
            }
        case .device:
            if indexPath.row < ruuviTags.count {
                let device = ruuviTags[indexPath.row]
                output.viewDidChoose(device: device, displayName: displayName(for: device))
            }
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionType = DiscoverTableSection.section(for: section, deviceCount: ruuviTags.count)
        if sectionType == .webTag {
            return 60
        } else {
            return super.tableView(tableView, heightForHeaderInSection: section)
        }
    }

    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 40
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let sectionType = DiscoverTableSection.section(for: section, deviceCount: ruuviTags.count)
        if sectionType == .webTag {
            // swiftlint:disable force_cast
            let header = tableView
                .dequeueReusableHeaderFooterView(withIdentifier: webTagsInfoSectionHeaderReuseIdentifier)
                as! DiscoverWebTagsInfoHeaderFooterView
            // swiftlint:enable force_cast
            header.delegate = self
            return header
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionType = DiscoverTableSection.section(for: section, deviceCount: ruuviTags.count)
        switch sectionType {
        case .device:
            return ruuviTags.count > 0 ? "DiscoverTable.SectionTitle.Devices".localized(for: Self.self) : nil
        case .noDevices:
            return ruuviTags.count == 0 ? "DiscoverTable.SectionTitle.Devices".localized(for: Self.self) : nil
        default:
            return nil
        }
    }
}

// MARK: - DiscoverWebTagsInfoHeaderFooterViewDelegate
extension DiscoverTableViewController: DiscoverWebTagsInfoHeaderFooterViewDelegate {
    func discoverWebTagsInfo(headerView: DiscoverWebTagsInfoHeaderFooterView, didTapOnInfo button: UIButton) {
        output.viewDidTapOnWebTagInfo()
    }
}

// MARK: - Cell configuration
extension DiscoverTableViewController {
    private func configure(cell: DiscoverWebTagTableViewCell, with tag: DiscoverVirtualTagViewModel) {
        cell.nameLabel.text = tag.locationType.title
        cell.iconImageView.image = tag.icon
    }

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
        configureTableView()
        configureBTDisabledImageView()
    }

    private func configureTableView() {
        tableView.rowHeight = 44
        let nib = UINib.nibName("DiscoverWebTagsInfoHeaderFooterView", for: Self.self)
        tableView.register(nib, forHeaderFooterViewReuseIdentifier: webTagsInfoSectionHeaderReuseIdentifier)
    }

    private func configureBTDisabledImageView() {
        btDisabledImageView.tintColor = .red
    }
}

// MARK: - Update UI
extension DiscoverTableViewController {
    private func updateUI() {
        updateTableView()
        updateUIISBluetoothEnabled()
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

    private func updateUIISBluetoothEnabled() {
        if isViewLoaded {
            emptyDataSetView = isBluetoothEnabled ? getMoreSensorsEmptyDataSetView : btDisabledEmptyDataSetView
        }
    }

    private func updateTableView() {
        if isViewLoaded {
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
}
// swiftlint:enable file_length
