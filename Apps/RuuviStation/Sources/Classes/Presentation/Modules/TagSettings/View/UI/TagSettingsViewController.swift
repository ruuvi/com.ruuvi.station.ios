import RuuviLocalization
import RuuviOntology
import RuuviService
// swiftlint:disable file_length
import UIKit

enum TagSettingsSectionHeaderType {
    case simple
    case expandable
}

enum TagSettingsSectionIdentifier {
    case general
    case btPair
    case alertHeader
    case alertTemperature
    case alertHumidity
    case alertPressure
    case alertRSSI
    case alertMovement
    case alertConnection
    case alertCloudConnection
    case offsetCorrection
    case moreInfo
    case firmware
    case remove
}

enum TagSettingsItemCellIdentifier: Int {
    case generalName = 0
    case generalOwner = 1
    case generalOwnersPlan = 2
    case generalShare = 3
    case offsetTemperature = 4
    case offsetHumidity = 5
    case offsetPressure = 6
}

class TagSettingsSection {
    init(
        identifier: TagSettingsSectionIdentifier,
        title: String,
        cells: [TagSettingsItem],
        collapsed: Bool,
        headerType: TagSettingsSectionHeaderType,
        backgroundColor: UIColor? = nil,
        font: UIFont? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.cells = cells
        self.collapsed = collapsed
        self.headerType = headerType
        self.backgroundColor = backgroundColor
        self.font = font
    }

    var identifier: TagSettingsSectionIdentifier
    var title: String
    var cells: [TagSettingsItem]
    var collapsed: Bool
    var headerType: TagSettingsSectionHeaderType
    var backgroundColor: UIColor?
    var font: UIFont?
}

struct TagSettingsItem {
    var identifier: TagSettingsItemCellIdentifier?
    var createdCell: () -> UITableViewCell
    var action: ((TagSettingsItem) -> Swift.Void)?
}

// swiftlint:disable:next type_body_length
class TagSettingsViewController: UIViewController {
    var output: TagSettingsViewOutput!
    var measurementService: RuuviServiceMeasurement!
    var viewModel: TagSettingsViewModel? {
        didSet {
            configureSections()
            updateUI()
            bindViewModel()
        }
    }

    var dashboardSortingType: DashboardSortingType?

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

    private lazy var exportButton: UIButton = {
        let button = UIButton()
        button.tintColor = .label
        let buttonImage = UIImage(systemName: "square.and.arrow.up")
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .label
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(exportButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = .clear
        tv.separatorStyle = .none
        tv.showsVerticalScrollIndicator = false
        tv.delegate = self
        tv.dataSource = self
        tv.sectionFooterHeight = 0
        return tv
    }()

    private lazy var headerContentView = TagSettingsBackgroundSelectionView()

    private lazy var numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }()

    /// The limit for the tag name is 32 characters
    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32
    private var customAlertDescriptionTextField = UITextField()
    private let customAlertDescriptionCharacterLimit = 32
    private var alertMinRangeTextField = UITextField()
    private var alertMaxRangeTextField = UITextField()
    private var cloudConnectionAlertDelayTextField = UITextField()
    private let cloudConnectionAlertDelayCharaterLimit: Int = 2

    private let pairedString = RuuviLocalization.TagSettings.PairAndBackgroundScan.Paired.title
    private let pairingString = RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title
    private let unpairedString = RuuviLocalization.TagSettings.PairAndBackgroundScan.Unpaired.title

    private let temperatureAlertFormat = RuuviLocalization.TagSettings.TemperatureAlertTitleLabel.text
    private let airHumidityAlertFormat = RuuviLocalization.TagSettings.AirHumidityAlert.title
    private let pressureAlertFormat = RuuviLocalization.TagSettings.PressureAlert.title

    // Cell
    static let ReuseIdentifier = "SettingsCell"
    private var tableViewSections = [TagSettingsSection]()

    // Weak reference to the cells
    // General section
    private lazy var tagNameCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var tagOwnerCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var tagOwnersPlanCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var tagShareCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Bluetooth section
    private lazy var btPairCell: TagSettingsSwitchCell? = TagSettingsSwitchCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Alerts
    // Temperature
    private lazy var temperatureAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var temperatureAlertSection: TagSettingsSection? = {
        let sectionTitle = temperatureAlertFormat(
            viewModel?.temperatureUnit.value?.symbol ?? RuuviLocalization.na
        )
        let section = TagSettingsSection(
            identifier: .alertTemperature,
            title: sectionTitle,
            cells: [
                termperatureAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }()

    private lazy var temperatureAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Humidity
    private lazy var humidityAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var humidityAlertSection: TagSettingsSection? = {
        let symbol = HumidityUnit.percent.symbol
        let sectionTitle = airHumidityAlertFormat(symbol)
        let section = TagSettingsSection(
            identifier: .alertHumidity,
            title: sectionTitle,
            cells: [
                humidityAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }()

    private lazy var humidityAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Pressure
    private lazy var pressureAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var pressureAlertSection: TagSettingsSection? = {
        let sectionTitle = pressureAlertFormat(
            viewModel?.pressureUnit.value?.symbol ?? RuuviLocalization.na
        )
        let section = TagSettingsSection(
            identifier: .alertPressure,
            title: sectionTitle,
            cells: [
                pressureAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }()

    private lazy var pressureAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // RSSI
    private lazy var rssiAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var rssiAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Movement
    private lazy var movementAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var movementAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Connection
    private lazy var connectionAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var connectionAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Cloud Connection
    private lazy var cloudConnectionAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var cloudConnectionAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Offset correction
    private lazy var tempOffsetCorrectionCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var humidityOffsetCorrectionCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var pressureOffsetCorrectionCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // More Info section
    private lazy var moreInfoSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var moreInfoMacAddressCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoDataFormatCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoDataSourceCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoBatteryVoltageCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoAccXCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoAccYCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoAccZCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoTxPowerCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoRSSICell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    private lazy var moreInfoMSNCell: TagSettingsPlainCell? = TagSettingsPlainCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Firmware section
    private lazy var firmwareVersionCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    deinit {
        tagNameCell = nil
        tagOwnerCell = nil
        tagOwnersPlanCell = nil
        tagShareCell = nil
        btPairCell = nil
        temperatureAlertSection = nil
        temperatureAlertSectionHeaderView = nil
        temperatureAlertCell = nil
        humidityAlertCell = nil
        humidityAlertSectionHeaderView = nil
        pressureAlertSection = nil
        pressureAlertSectionHeaderView = nil
        pressureAlertCell = nil
        rssiAlertSectionHeaderView = nil
        rssiAlertCell = nil
        movementAlertSectionHeaderView = nil
        movementAlertCell = nil
        connectionAlertSectionHeaderView = nil
        connectionAlertCell = nil
        cloudConnectionAlertSectionHeaderView = nil
        cloudConnectionAlertCell = nil
        tempOffsetCorrectionCell = nil
        humidityOffsetCorrectionCell = nil
        pressureOffsetCorrectionCell = nil
        moreInfoSectionHeaderView = nil
        moreInfoMacAddressCell = nil
        moreInfoDataFormatCell = nil
        moreInfoDataSourceCell = nil
        moreInfoBatteryVoltageCell = nil
        moreInfoAccXCell = nil
        moreInfoAccYCell = nil
        moreInfoAccZCell = nil
        moreInfoTxPowerCell = nil
        moreInfoRSSICell = nil
        moreInfoMSNCell = nil
        firmwareVersionCell = nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        localize()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }
}

// MARK: - BINDINGS

extension TagSettingsViewController {
    private func bindViewModel() {
        bindBackgroundView()
        bindGeneralSection()
        bindBluetoothSection()
        bindAlertsSection()
        bindOffsetCorrectionSection()
        bindMoreInfoSection()
        bindFirmwareSection()
    }
}

// MARK: - CONFIGURATION

extension TagSettingsViewController {
    private func configureSections() {
        tableViewSections = []

        // Fixed item on top - general and bluetooth.
        tableViewSections += [
            configureGeneralSection(),
            configureBluetoothSection(),
        ]

        // Variable items
        // Alerts
        tableViewSections += configureAlertSections()

        // Offset correction
        if showOffsetCorrection() {
            tableViewSections
                .append(configureOffsetCorrectionSection())
        }

        // Fixed item at bottom - more info, firmware and remove.
        tableViewSections += [
            configureMoreInfoSection(),
            configureFirmwareSection(),
            configureRemoveSection(),
        ]
    }

    private func updateUI() {
        tableView.reloadData()
    }

    private func reloadSection(index: Int) {
        let section = NSIndexSet(index: index) as IndexSet
        tableView.reloadSections(section, with: .fade)
    }

    // swiftlint:disable:next function_body_length
    private func reloadSection(identifier: TagSettingsSectionIdentifier) {
        switch identifier {
        case .btPair:
            let section = configureBluetoothSection()
            updateSection(
                with: identifier,
                newSection: section
            )
        case .offsetCorrection:
            if showOffsetCorrection() {
                let section = configureOffsetCorrectionSection()
                updateSection(
                    with: identifier,
                    newSection: section
                )
            } else {
                if tableViewSections.firstIndex(
                    where: { $0.identifier == identifier }
                ) != nil {
                    removeSection(with: .offsetCorrection)
                }
            }
        case .alertCloudConnection:
            let newSection = configureCloudConnectionAlertSection()
            if let index = tableViewSections.firstIndex(
                where: { $0.identifier == identifier }
            ) {
                // If section exists but it is not supposed to be visible because
                // of owners plan being lower than pro, delete the section.
                UIView.setAnimationsEnabled(false)
                tableView.performBatchUpdates({
                    if !cloudConnectionAlertVisible() {
                        // Updating data source
                        tableViewSections.remove(at: index)
                        let indexSet = IndexSet(integer: index)
                        // Updating UITableView
                        tableView.deleteSections(indexSet, with: .none)
                    }
                }, completion: nil)
                UIView.setAnimationsEnabled(true)
            } else {
                // If section doesn't exist and it supposed to be visible, find the
                // index of the Connection alert section, and insert new section on index+1 position
                // since Cloud Connection section should go below that.
                if cloudConnectionAlertVisible() {
                    if let index = tableViewSections.firstIndex(
                        where: { $0.identifier == .alertConnection }
                    ) {
                        let newIndex = index + 1
                        UIView.setAnimationsEnabled(false)
                        tableView.performBatchUpdates({
                            // Updating data source
                            tableViewSections.insert(newSection, at: newIndex)
                            // Updating UITableView
                            let indexSet = IndexSet(integer: newIndex)
                            tableView.insertSections(indexSet, with: .none)
                        }, completion: nil)
                        UIView.setAnimationsEnabled(true)
                    }
                }
            }
        default:
            break
        }
    }

    private func updateSection(
        with identifier: TagSettingsSectionIdentifier,
        newSection: TagSettingsSection
    ) {
        if let index = tableViewSections.firstIndex(
            where: { $0.identifier == identifier }
        ) {
            UIView.setAnimationsEnabled(false)
            tableView.performBatchUpdates({
                // Updating data source
                tableViewSections.remove(at: index)
                tableViewSections.insert(newSection, at: index)
                // Updating UITableView
                let indexSet = IndexSet(integer: index)
                tableView.deleteSections(indexSet, with: .none)
                tableView.insertSections(indexSet, with: .none)
            }, completion: nil)
            UIView.setAnimationsEnabled(true)
        }
    }

    private func removeSection(
        with indentifier: TagSettingsSectionIdentifier
    ) {
        if let index = tableViewSections.firstIndex(where: {
            $0.identifier == indentifier
        }) {
            let indexSet = NSIndexSet(index: index) as IndexSet
            UIView.setAnimationsEnabled(false)
            tableView.performBatchUpdates({
                tableViewSections.remove(at: index)
                tableView.deleteSections(indexSet, with: .none)
            })
            UIView.setAnimationsEnabled(true)
        }
    }

    private func reloadCellsFor(section: TagSettingsSectionIdentifier) {
        switch section {
        case .general:
            if let currentSection = tableViewSections.first(where: {
                $0.identifier == section
            }) {
                let availableItems = itemsForGeneralSection(showPlan: true)

                let sectionIndex = indexOfSection(section: section)
                var oldIndexPaths: [IndexPath] = []
                for rowIndex in 0 ..< currentSection.cells.count {
                    let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                    oldIndexPaths.append(indexPath)
                }

                // Prepare new indexPaths for availableItems
                var newIndexPaths: [IndexPath] = []
                for rowIndex in 0 ..< availableItems.count {
                    let indexPath = IndexPath(row: rowIndex, section: sectionIndex)
                    newIndexPaths.append(indexPath)
                }

                UIView.setAnimationsEnabled(false)
                tableView.performBatchUpdates({
                    currentSection.cells = availableItems
                    tableView.deleteRows(at: oldIndexPaths, with: .none)
                    tableView.insertRows(at: newIndexPaths, with: .none)
                }, completion: nil)
                UIView.setAnimationsEnabled(true)
            }
        default:
            break
        }
    }

    private func indexOfSection(section: TagSettingsSectionIdentifier) -> Int {
        tableViewSections.firstIndex(where: {
            $0.identifier == section
        }) ?? tableViewSections.count
    }
}

// MARK: - HEADER VIEW

extension TagSettingsViewController {
    private func bindBackgroundView() {
        guard let viewModel
        else {
            return
        }

        headerContentView.bind(viewModel.background) { header, background in
            header.setBackgroundImage(with: background)
        }
    }
}

// MARK: - GENERAL SECTION

extension TagSettingsViewController {
    private func bindGeneralSection() {
        guard let viewModel
        else {
            return
        }

        if let tagNameCell {
            tagNameCell.bind(viewModel.name) { cell, name in
                cell.configure(value: name)
            }
        }

        if let tagOwnerCell {
            tagOwnerCell.bind(viewModel.owner) { cell, owner in
                cell.configure(value: owner)
                cell.setAccessory(type: .chevron)
            }
        }

        if let tagOwnersPlanCell {
            tagOwnersPlanCell.bind(viewModel.ownersPlan) { cell, ownersPlan in
                cell.configure(value: ownersPlan)
            }
        }

        if let tagShareCell {
            tagShareCell.bind(viewModel.sharedTo) { [weak self] cell, sharedTo in
                cell.configure(value: self?.sensorSharedTo(from: sharedTo))
            }
        }

        tableView.bind(viewModel.isOwner) { _, _ in
            self.reloadCellsFor(section: .general)
        }

        tableView.bind(viewModel.sharedTo) { _, _ in
            self.reloadCellsFor(section: .general)
        }

        tableView.bind(viewModel.canShareTag) { _, _ in
            self.reloadCellsFor(section: .general)
        }
    }

    private func itemsForGeneralSection(showPlan: Bool = false) -> [TagSettingsItem] {
        var availableItems: [TagSettingsItem] = [
            tagNameSettingItem()
        ]
        if showOwner() {
            availableItems.append(tagOwnerSettingItem())
            if let isOwner = viewModel?.isOwner.value, !isOwner,
               let isCloudTag = viewModel?.isNetworkConnected.value,
               isCloudTag, showPlan {
                availableItems.append(tagOwnersPlanSettingItem())
            }
        }
        if showShare() {
            availableItems.append(tagShareSettingItem())
        }
        return availableItems
    }

    private func configureGeneralSection() -> TagSettingsSection {
        let availableItems = itemsForGeneralSection()
        let section = TagSettingsSection(
            identifier: .general,
            title: RuuviLocalization.TagSettings.SectionHeader.General.title.capitalized,
            cells: availableItems,
            collapsed: false,
            headerType: .simple
        )
        return section
    }

    private func tagNameSettingItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            identifier: .generalName,
            createdCell: { [weak self] in
                self?.tagNameCell?.configure(
                    title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
                    value: self?.viewModel?.name.value
                )
                self?.tagNameCell?.setAccessory(type: .pencil)
                return self?.tagNameCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                guard let sortingType = self?.dashboardSortingType else { return }
                self?.showSensorNameRenameDialog(
                    name: self?.viewModel?.name.value,
                    sortingType: sortingType
                )
            }
        )
        return settingItem
    }

    private func tagOwnerSettingItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            identifier: .generalOwner,
            createdCell: { [weak self] in
                self?.tagOwnerCell?.configure(
                    title: RuuviLocalization.TagSettings.NetworkInfo.owner,
                    value: self?.viewModel?.owner.value
                )
                self?.tagOwnerCell?.setAccessory(type: .chevron)
                self?.tagOwnerCell?.hideSeparator(hide: false)
                return self?.tagOwnerCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                self?.output.viewDidTapOnOwner()
            }
        )
        return settingItem
    }

    private func tagOwnersPlanSettingItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            identifier: .generalOwnersPlan,
            createdCell: { [weak self] in
                self?.tagOwnersPlanCell?.configure(
                    title: RuuviLocalization.ownersPlan,
                    value: self?.viewModel?.ownersPlan.value
                )
                self?.tagOwnersPlanCell?.setAccessory(type: .none)
                self?.tagOwnersPlanCell?.hideSeparator(hide: !GlobalHelpers.getBool(from: self?.showShare()))
                return self?.tagOwnersPlanCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func tagShareSettingItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            identifier: .generalShare,
            createdCell: { [weak self] in
                self?.tagShareCell?.configure(
                    title: RuuviLocalization.TagSettings.Share.title,
                    value: self?.sensorSharedTo(
                        from: self?.viewModel?.sharedTo.value
                    )
                )
                self?.tagShareCell?.setAccessory(type: .chevron)
                self?.tagShareCell?.hideSeparator(hide: true)
                return self?.tagShareCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                self?.output.viewDidTapShareButton()
            }
        )
        return settingItem
    }

    private func showOwner() -> Bool {
        viewModel?.isAuthorized.value == true
    }

    private func isOwner() -> Bool {
        viewModel?.isOwner.value == true
    }

    private func showShare() -> Bool {
        viewModel?.canShareTag.value == true
    }

    private func sensorSharedTo(from: [String]?) -> String {
        let maxShareCount = 10
        if let sharedTo = from, sharedTo.count > 0 {
            return RuuviLocalization.sharedToX(sharedTo.count, maxShareCount)
        } else {
            return RuuviLocalization.TagSettings.NotShared.title
        }
    }
}

// MARK: - BLUETOOTH SECTION

extension TagSettingsViewController: TagSettingsSwitchCellDelegate {
    // swiftlint:disable:next function_body_length
    private func bindBluetoothSection() {
        guard let viewModel
        else {
            return
        }

        if let btPairCell {
            btPairCell.bind(viewModel.isConnected) {
                [weak self] cell,
                isConnected in
                cell.configureSwitch(
                    value: isConnected.bound,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
                cell.disableSwitch(disable: false)
                self?.reloadAlertSectionHeaders()
            }

            btPairCell.bind(viewModel.keepConnection) { cell, keepConnection in
                cell.configureSwitch(
                    value: keepConnection.bound,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            let keepConnection = viewModel.keepConnection
            btPairCell.bind(viewModel.isConnected) {
                [weak self,
                 weak keepConnection] cell, isConnected in
                let keep = keepConnection?.value ?? false
                if isConnected.bound {
                    // Connected state
                    cell.configure(title: self?.pairedString)
                    cell.configurePairingAnimation(start: false)
                } else if keep {
                    // When trying to connect
                    cell.configure(title: self?.pairingString)
                    cell.configurePairingAnimation(start: true)
                } else {
                    // Disconnected state
                    cell.configure(title: self?.unpairedString)
                    cell.configurePairingAnimation(start: false)
                }
                self?.reloadSection(identifier: .btPair)
            }

            let isConnected = viewModel.isConnected
            btPairCell.bind(viewModel.keepConnection) {
                [weak self,
                 weak isConnected] cell, keepConnection in
                let isConnected = isConnected?.value ?? false
                if isConnected {
                    // Connected state
                    cell.configure(title: self?.pairedString)
                    cell.configurePairingAnimation(start: false)
                } else if keepConnection.bound {
                    // When trying to connect
                    cell.configure(title: self?.pairingString)
                    cell.configurePairingAnimation(start: true)
                } else {
                    // Disconnected state
                    cell.configure(title: self?.unpairedString)
                    cell.configurePairingAnimation(start: false)
                }
                self?.reloadSection(identifier: .btPair)
            }
        }
    }

    private func configureBluetoothSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .btPair,
            title: RuuviLocalization.TagSettings.SectionHeader.BTConnection.title.capitalized,
            cells: [
                tagPairSettingItem(),
                tagPairFooterItem(),
            ],
            collapsed: false,
            headerType: .simple
        )
        return section
    }

    private func tagPairSettingItem() -> TagSettingsItem {
        let isConnected = viewModel?.isConnected.value ?? false
        let keep = viewModel?.keepConnection.value ?? false
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                if isConnected {
                    // Connected state
                    self?.btPairCell?.configure(title: self?.pairedString)
                    self?.btPairCell?.configurePairingAnimation(start: false)
                } else if keep {
                    // When trying to connect
                    self?.btPairCell?.configure(title: self?.pairingString)
                    self?.btPairCell?.configurePairingAnimation(start: true)
                } else {
                    // Disconnected state
                    self?.btPairCell?.configure(title: self?.unpairedString)
                    self?.btPairCell?.configurePairingAnimation(start: false)
                }
                self?.btPairCell?.delegate = self
                return self?.btPairCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func tagPairFooterItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: {
                let cell = TagSettingsFooterCell(style: .value1, reuseIdentifier: Self.ReuseIdentifier)
                cell.configure(value: RuuviLocalization.TagSettings.PairAndBackgroundScan.description)
                return cell
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - TAG_SETTINGS_SWITCH_CELL_DELEGATE

    func didToggleSwitch(isOn: Bool, sender: TagSettingsSwitchCell) {
        if let btPairCell, sender == btPairCell {
            output.viewDidTriggerKeepConnection(isOn: isOn)
        }
    }
}

// MARK: - ALERTS SECTION

extension TagSettingsViewController {
    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func bindAlertsSection() {
        guard let viewModel
        else {
            return
        }

        // Temperature
        tableView.bind(viewModel.temperatureUnit) { [weak self] _, value in
            guard let sSelf = self else { return }
            sSelf.temperatureAlertSection?.title = sSelf.temperatureAlertFormat(
                value?.symbol ?? RuuviLocalization.na
            )
        }

        if let temperatureAlertCell {
            temperatureAlertCell.bind(viewModel.isTemperatureAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            temperatureAlertCell.bind(viewModel.temperatureAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            temperatureAlertCell.bind(viewModel.temperatureUpperBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.temperatureAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.temperatureLowerBound(),
                    selectedMaxValue: self?.temperatureUpperBound()
                )
            }

            temperatureAlertCell.bind(viewModel.temperatureLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.temperatureAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.temperatureLowerBound(),
                    selectedMaxValue: self?.temperatureUpperBound()
                )
            }

            temperatureAlertCell.bind(viewModel.temperatureUnit) {
                [weak self] cell, _ in
                guard let sSelf = self else { return }
                sSelf.updateTemperatureAlertSlider(for: cell)
            }

            temperatureAlertCell.bind(viewModel.latestMeasurement) { cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertTemperature
                )
            }

            temperatureAlertCell.bind(viewModel.showCustomTempAlertBound) {
                [weak self] cell, _ in
                guard let sSelf = self else { return }
                sSelf.updateTemperatureAlertSlider(for: cell)
            }
        }

        if let temperatureAlertSectionHeaderView {
            temperatureAlertSectionHeaderView.bind(viewModel.temperatureUnit) { [weak self]
                header, unit in
                    guard let sSelf = self else { return }
                    let sectionTitle = sSelf.temperatureAlertFormat(
                        unit?.symbol ?? RuuviLocalization.na
                    )
                    header.setTitle(with: sectionTitle)
            }

            temperatureAlertSectionHeaderView.bind(
                viewModel.temperatureAlertMutedTill) { header, mutedTill in
                    let isOn = self.alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isTemperatureAlertOn.value)
                    let alertState = viewModel.temperatureAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            temperatureAlertSectionHeaderView
                .bind(viewModel.isTemperatureAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let mutedTill = viewModel.temperatureAlertMutedTill.value
                    let alertState = viewModel.temperatureAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            temperatureAlertSectionHeaderView
                .bind(viewModel.temperatureAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isTemperatureAlertOn.value)
                    let mutedTill = viewModel.temperatureAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Humidity

        if let humidityAlertCell {
            humidityAlertCell.bind(viewModel.isRelativeHumidityAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            humidityAlertCell.bind(viewModel.relativeHumidityAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            humidityAlertCell.bind(viewModel.relativeHumidityUpperBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.humidityAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.humidityLowerBound(),
                    selectedMaxValue: self?.humidityUpperBound()
                )
            }

            humidityAlertCell.bind(viewModel.relativeHumidityLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.humidityAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.humidityLowerBound(),
                    selectedMaxValue: self?.humidityUpperBound()
                )
            }

            humidityAlertCell.bind(viewModel.humidityUnit) {
                [weak self] cell, _ in
                guard let sSelf = self else { return }
                let (minRange, maxRange) = sSelf.humidityMinMaxForSliders()
                cell.setAlertLimitDescription(description: sSelf.humidityAlertRangeDescription())
                cell.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: sSelf.humidityLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: sSelf.humidityUpperBound()
                )
            }

            humidityAlertCell.bind(viewModel.latestMeasurement) {
                [weak self] cell, measurement in
                guard let sSelf = self else { return }
                cell.disableEditing(
                    disable: measurement == nil || !sSelf.showHumidityOffsetCorrection(),
                    identifier: .alertHumidity
                )
            }
        }

        if let humidityAlertSectionHeaderView {
            humidityAlertSectionHeaderView.bind(
                viewModel.relativeHumidityAlertMutedTill) { [weak self] header, mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isRelativeHumidityAlertOn.value)
                    let alertState = viewModel.relativeHumidityAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            humidityAlertSectionHeaderView
                .bind(viewModel.isRelativeHumidityAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.relativeHumidityAlertState.value
                    let mutedTill = viewModel.relativeHumidityAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            humidityAlertSectionHeaderView
                .bind(viewModel.relativeHumidityAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isRelativeHumidityAlertOn.value)
                    let mutedTill = viewModel.relativeHumidityAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Pressure
        tableView.bind(viewModel.pressureUnit) { [weak self] _, value in
            guard let sSelf = self else { return }
            sSelf.pressureAlertSection?.title = sSelf.pressureAlertFormat(
                value?.symbol ?? RuuviLocalization.na
            )
        }

        if let pressureAlertCell {
            pressureAlertCell.bind(viewModel.isPressureAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            pressureAlertCell.bind(viewModel.pressureAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            pressureAlertCell.bind(viewModel.pressureUpperBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.pressureAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.pressureLowerBound(),
                    selectedMaxValue: self?.pressureUpperBound()
                )
            }

            pressureAlertCell.bind(viewModel.pressureLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.pressureAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.pressureLowerBound(),
                    selectedMaxValue: self?.pressureUpperBound()
                )
            }

            pressureAlertCell.bind(viewModel.pressureUnit) {
                [weak self] cell, _ in
                guard let sSelf = self else { return }
                let (minRange, maxRange) = sSelf.pressureMinMaxForSliders()
                cell.setAlertLimitDescription(description: sSelf.humidityAlertRangeDescription())
                cell.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: sSelf.pressureLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: sSelf.pressureUpperBound()
                )
            }

            pressureAlertCell.bind(viewModel.latestMeasurement) {
                [weak self] cell, measurement in
                guard let sSelf = self else { return }
                cell.disableEditing(
                    disable: measurement == nil || !sSelf.showPressureOffsetCorrection(),
                    identifier: .alertPressure
                )
            }
        }

        if let pressureAlertSectionHeaderView {
            pressureAlertSectionHeaderView.bind(viewModel.pressureUnit) {
                [weak self] header, unit in
                guard let sSelf = self else { return }
                let sectionTitle = sSelf.pressureAlertFormat(
                    unit?.symbol ?? RuuviLocalization.na
                )
                header.setTitle(with: sectionTitle)
            }

            pressureAlertSectionHeaderView.bind(
                viewModel.pressureAlertMutedTill) { header, mutedTill in
                    let isOn = self.alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isPressureAlertOn.value)
                    let alertState = viewModel.pressureAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pressureAlertSectionHeaderView
                .bind(viewModel.isPressureAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.pressureAlertState.value
                    let mutedTill = viewModel.pressureAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pressureAlertSectionHeaderView
                .bind(viewModel.pressureAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isPressureAlertOn.value)
                    let mutedTill = viewModel.pressureAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // RSSI
        if let rssiAlertCell {
            rssiAlertCell.bind(viewModel.isSignalAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            rssiAlertCell.bind(viewModel.signalAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?
                    .alertCustomDescription(from: value))
            }

            rssiAlertCell.bind(viewModel.signalUpperBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.rssiAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.rssiLowerBound(),
                    selectedMaxValue: self?.rssiUpperBound()
                )
            }

            rssiAlertCell.bind(viewModel.signalLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.rssiAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.rssiLowerBound(),
                    selectedMaxValue: self?.rssiUpperBound()
                )
            }

            rssiAlertCell.bind(viewModel.latestMeasurement) { cell, measurement in
                let isClaimed = GlobalHelpers.getBool(from: viewModel.isClaimedTag.value)
                cell.disableEditing(
                    disable: measurement == nil || !isClaimed,
                    identifier: .alertRSSI
                )
            }

            rssiAlertCell.bind(viewModel.isClaimedTag) { [weak self] cell, isClaimed in
                let hasMeasurement = GlobalHelpers.getBool(from: self?.hasMeasurement())
                cell.disableEditing(
                    disable: !hasMeasurement || !GlobalHelpers.getBool(from: isClaimed),
                    identifier: .alertRSSI
                )
                // Disable active signal alert if tag is unclaimed.
                if !isClaimed.bound,
                    let isSignalAlertOn = self?.viewModel?.isSignalAlertOn.value,
                   isSignalAlertOn {
                    self?.output.viewDidChangeAlertState(
                        for: .signal(lower: 0, upper: 0),
                        isOn: false
                    )
                }
            }
        }

        if let rssiAlertSectionHeaderView {
            rssiAlertSectionHeaderView.bind(
                viewModel.signalAlertMutedTill) { [weak self] header, mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isSignalAlertOn.value)
                    let alertState = viewModel.signalAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            rssiAlertSectionHeaderView
                .bind(viewModel.isSignalAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.signalAlertState.value
                    let mutedTill = viewModel.signalAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            rssiAlertSectionHeaderView
                .bind(viewModel.signalAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isSignalAlertOn.value)
                    let mutedTill = viewModel.signalAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Movement
        if let movementAlertCell {
            movementAlertCell.bind(viewModel.isMovementAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            movementAlertCell.bind(viewModel.movementAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            movementAlertCell.bind(viewModel.latestMeasurement) {
                [weak self] cell, measurement in
                guard let sSelf = self else { return }
                cell.disableEditing(
                    disable: measurement == nil || sSelf.viewModel?.movementCounter.value == nil,
                    identifier: .alertMovement
                )
            }
        }

        if let movementAlertSectionHeaderView {
            movementAlertSectionHeaderView.bind(
                viewModel.movementAlertMutedTill) { [weak self] header, mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isMovementAlertOn.value)
                    let alertState = viewModel.movementAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            movementAlertSectionHeaderView
                .bind(viewModel.isMovementAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.movementAlertState.value
                    let mutedTill = viewModel.movementAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            movementAlertSectionHeaderView
                .bind(viewModel.movementAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isMovementAlertOn.value)
                    let mutedTill = viewModel.movementAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Connection
        if let connectionAlertCell {
            connectionAlertCell.bind(viewModel.isConnectionAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            connectionAlertCell.bind(viewModel.connectionAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            connectionAlertCell.bind(viewModel.latestMeasurement) { cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertConnection
                )
            }
        }

        if let connectionAlertSectionHeaderView {
            connectionAlertSectionHeaderView.bind(
                viewModel.connectionAlertMutedTill) { [weak self] header, mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isConnectionAlertOn.value)
                    let alertState = viewModel.connectionAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            connectionAlertSectionHeaderView
                .bind(viewModel.isConnectionAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.connectionAlertState.value
                    let mutedTill = viewModel.connectionAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            connectionAlertSectionHeaderView
                .bind(viewModel.connectionAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isConnectionAlertOn.value)
                    let mutedTill = viewModel.connectionAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Cloud Connection
        tableView.bind(viewModel.isCloudConnectionAlertsAvailable) {
            [weak self] _, _ in
            self?.reloadSection(identifier: .alertCloudConnection)
        }

        if let cloudConnectionAlertCell {
            cloudConnectionAlertCell.bind(viewModel.isCloudConnectionAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            cloudConnectionAlertCell.bind(viewModel.cloudConnectionAlertUnseenDuration) {
                [weak self] cell, duration in
                guard let durationInt = duration?.intValue, durationInt >= 60
                else {
                    return
                }

                cell.setAlertLimitDescription(
                    description: self?.cloudConnectionAlertRangeDescription(from: durationInt / 60)
                )
            }

            cloudConnectionAlertCell.bind(viewModel.cloudConnectionAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }
        }

        if let cloudConnectionAlertSectionHeaderView {
            cloudConnectionAlertSectionHeaderView.bind(
                viewModel.cloudConnectionAlertMutedTill) { [weak self] header, mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isCloudConnectionAlertOn.value)
                    let alertState = viewModel.cloudConnectionAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            cloudConnectionAlertSectionHeaderView
                .bind(viewModel.isCloudConnectionAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.cloudConnectionAlertState.value
                    let mutedTill = viewModel.cloudConnectionAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            cloudConnectionAlertSectionHeaderView
                .bind(viewModel.cloudConnectionAlertState) { [weak self] header, state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: viewModel.isCloudConnectionAlertOn.value)
                    let mutedTill = viewModel.cloudConnectionAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }
    }

    private func configureAlertSections() -> [TagSettingsSection] {
        var sections: [TagSettingsSection] = []

        // Fixed items
        sections += [
            configureAlertHeaderSection(),
            configureTemperatureAlertSection(),
            configureHumidityAlertSection(),
            configurePressureAlertSection(),
            configureRSSIAlertSection(),
            configureMovementAlertSection(),
            configureConnectionAlertSection(),
        ]

        if cloudConnectionAlertVisible() {
            sections += [
                configureCloudConnectionAlertSection()
            ]
        }

        return sections
    }

    private func configureAlertHeaderSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .alertHeader,
            title: RuuviLocalization.TagSettings.Label.Alerts.text.capitalized,
            cells: [],
            collapsed: false,
            headerType: .simple
        )
        return section
    }

    // MARK: - TEMPERATURE ALERTS

    private func configureTemperatureAlertSection() -> TagSettingsSection {
        temperatureAlertSection!
    }

    private func termperatureAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = temperatureMinMaxForSliders()
        let disableTemperature = !hasMeasurement()
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.temperatureAlertCell?.setStatus(
                    with: self?.viewModel?.isTemperatureAlertOn.value,
                    hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                )
                self?.temperatureAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .temperatureAlertDescription.value))
                self?.temperatureAlertCell?
                    .setAlertLimitDescription(description: self?.temperatureAlertRangeDescription())
                self?.temperatureAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.temperatureLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.temperatureUpperBound()
                )
                self?.temperatureAlertCell?.disableEditing(
                    disable: disableTemperature,
                    identifier: .alertTemperature
                )
                self?.temperatureAlertCell?.delegate = self
                return self?.temperatureAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - HUMIDITY ALERTS

    private func configureHumidityAlertSection() -> TagSettingsSection {
        humidityAlertSection!
    }

    private func humidityAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = humidityMinMaxForSliders()
        let disableHumidity = !showHumidityOffsetCorrection() || !hasMeasurement()
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.humidityAlertCell?.setStatus(
                    with: self?.viewModel?.isRelativeHumidityAlertOn.value,
                    hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                )
                self?.humidityAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .relativeHumidityAlertDescription.value))
                self?.humidityAlertCell?
                    .setAlertLimitDescription(
                        description: self?.humidityAlertRangeDescription())
                self?.humidityAlertCell?
                    .setAlertRange(
                        minValue: minRange,
                        selectedMinValue: self?.humidityLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: self?.humidityUpperBound()
                    )
                self?.humidityAlertCell?.disableEditing(
                    disable: disableHumidity,
                    identifier: .alertHumidity
                )
                self?.humidityAlertCell?.delegate = self
                return self?.humidityAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - PRESSURE ALERTS

    private func configurePressureAlertSection() -> TagSettingsSection {
        pressureAlertSection!
    }

    private func pressureAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = pressureMinMaxForSliders()
        let disablePressure = !showPressureOffsetCorrection() || !hasMeasurement()
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.pressureAlertCell?.showAlertRangeSetter()
                self?.pressureAlertCell?.setStatus(
                    with: self?.viewModel?.isPressureAlertOn.value,
                    hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                )
                self?.pressureAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .pressureAlertDescription.value))
                self?.pressureAlertCell?
                    .setAlertLimitDescription(description: self?.pressureAlertRangeDescription())
                self?.pressureAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.pressureLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.pressureUpperBound()
                )
                self?.pressureAlertCell?.disableEditing(
                    disable: disablePressure,
                    identifier: .alertPressure
                )
                self?.pressureAlertCell?.delegate = self
                return self?.pressureAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - RSSI ALERTS

    private func configureRSSIAlertSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .alertRSSI,
            title: RuuviLocalization.signalStrengthDbm,
            cells: [
                rssiAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func rssiAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = rssiMinMaxForSliders()
        let disableRssi = !hasMeasurement() ||
            !GlobalHelpers.getBool(from: viewModel?.isClaimedTag.value)
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.rssiAlertCell?.showNoticeView()
                self?.rssiAlertCell?
                    .setNoticeText(with: RuuviLocalization.rssiAlertDescription)
                self?.rssiAlertCell?.showAlertRangeSetter()
                self?.rssiAlertCell?
                    .setStatus(
                        with: self?.viewModel?.isSignalAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.rssiAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .signalAlertDescription.value))
                self?.rssiAlertCell?
                    .setAlertLimitDescription(description: self?.rssiAlertRangeDescription())
                self?.rssiAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.rssiLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.rssiUpperBound()
                )
                self?.rssiAlertCell?.disableEditing(
                    disable: disableRssi,
                    identifier: .alertRSSI
                )
                self?.rssiAlertCell?.delegate = self
                return self?.rssiAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - MOVEMENT ALERTS

    private func configureMovementAlertSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .alertMovement,
            title: RuuviLocalization.TagSettings.MovementAlert.title,
            cells: [
                movementAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func movementAlertItem() -> TagSettingsItem {
        let disableMovement = viewModel?.movementCounter.value == nil ||
            !hasMeasurement()
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.movementAlertCell?
                    .setNoticeText(with: RuuviLocalization.TagSettings.Alerts.Movement.description)
                self?.movementAlertCell?.hideAlertRangeSetter()
                self?.movementAlertCell?.showNoticeView()
                self?.movementAlertCell?.hideAdditionalTextview()
                self?.movementAlertCell?.delegate = self
                self?.movementAlertCell?.disableEditing(
                    disable: disableMovement,
                    identifier: .alertMovement
                )
                return self?.movementAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - CONNECTION ALERTS

    private func configureConnectionAlertSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .alertConnection,
            title: RuuviLocalization.TagSettings.ConnectionAlert.title,
            cells: [
                connectionAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func connectionAlertItem() -> TagSettingsItem {
        let disableConnection = !hasMeasurement()
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.connectionAlertCell?
                    .setAlertAddtionalText(with: RuuviLocalization.TagSettings.Alerts.Connection.description)
                self?.connectionAlertCell?.hideAlertRangeSetter()
                self?.connectionAlertCell?.hideNoticeView()
                self?.connectionAlertCell?.showAdditionalTextview()
                self?.connectionAlertCell?.disableEditing(
                    disable: disableConnection,
                    identifier: .alertConnection
                )
                self?.connectionAlertCell?.delegate = self
                return self?.connectionAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - CLOUD CONNECTION ALERTS

    private func configureCloudConnectionAlertSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .alertCloudConnection,
            title: RuuviLocalization.alertCloudConnectionTitle,
            cells: [
                cloudConnectionAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func cloudConnectionAlertItem() -> TagSettingsItem {
        let duration = viewModel?.cloudConnectionAlertUnseenDuration.value?.intValue ?? 900
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.cloudConnectionAlertCell?.hideAlertRangeSlider()
                self?.cloudConnectionAlertCell?.showAlertLimitDescription()
                self?.cloudConnectionAlertCell?.hideNoticeView()
                self?.cloudConnectionAlertCell?.hideAdditionalTextview()
                self?.cloudConnectionAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .cloudConnectionAlertDescription.value))
                self?.cloudConnectionAlertCell?
                    .setAlertLimitDescription(
                        description: self?.cloudConnectionAlertRangeDescription(
                            from: duration / 60
                        )
                    )
                self?.cloudConnectionAlertCell?.delegate = self
                return self?.cloudConnectionAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - Alerts helpers

    private func alertsAvailable() -> Bool {
        (viewModel?.isCloudAlertsAvailable.value ?? false ||
            viewModel?.isConnected.value ?? false)
    }

    private func reloadAlertSectionHeaders() {
        reloadTemperatureAlertSectionHeader()
        reloadRHAlertSectionHeader()
        reloadPressureAlertSectionHeader()
        reloadSignalAlertSectionHeader()
        reloadMovementAlertSectionHeader()
        reloadConnectionAlertSectionHeader()
    }

    private func reloadTemperatureAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isTemperatureAlertOn.value
        )
        let mutedTill = viewModel?.temperatureAlertMutedTill.value
        let alertState = viewModel?.temperatureAlertState.value
        temperatureAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadRHAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isRelativeHumidityAlertOn.value
        )
        let mutedTill = viewModel?.relativeHumidityAlertMutedTill.value
        let alertState = viewModel?.relativeHumidityAlertState.value
        humidityAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadPressureAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isPressureAlertOn.value
        )
        let mutedTill = viewModel?.pressureAlertMutedTill.value
        let alertState = viewModel?.pressureAlertState.value
        pressureAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadSignalAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isSignalAlertOn.value
        )
        let mutedTill = viewModel?.signalAlertMutedTill.value
        let alertState = viewModel?.signalAlertState.value
        rssiAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadMovementAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isMovementAlertOn.value
        )
        let mutedTill = viewModel?.movementAlertMutedTill.value
        let alertState = viewModel?.movementAlertState.value
        movementAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadConnectionAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isConnectionAlertOn.value
        )
        let mutedTill = viewModel?.connectionAlertMutedTill.value
        let alertState = viewModel?.connectionAlertState.value
        connectionAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadCloudConnectionAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isCloudConnectionAlertOn.value
        )
        let mutedTill = viewModel?.cloudConnectionAlertMutedTill.value
        let alertState = viewModel?.cloudConnectionAlertState.value
        cloudConnectionAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func alertCustomDescription(from string: String?) -> String? {
        let alertPlaceholder = RuuviLocalization.TagSettings.Alert.CustomDescription.placeholder
        return string.hasText() ? string : alertPlaceholder
    }

    private func temperatureAlertRangeDescription(
        from min: CGFloat? = nil,
        max: CGFloat? = nil
    ) -> NSMutableAttributedString? {
        guard isViewLoaded else { return nil }
        let format = RuuviLocalization.TagSettings.Alerts.description
        if let min, let max {
            return attributedString(
                from: format(
                    formatNumber(
                        from: min
                    ),
                    formatNumber(
                        from: max
                    )
                )
            )
        }

        if let tu = viewModel?.temperatureUnit.value?.unitTemperature,
           let l = viewModel?.temperatureLowerBound.value?.converted(to: tu),
           let u = viewModel?.temperatureUpperBound.value?.converted(to: tu) {
            return attributedString(
                from: format(
                    formatNumber(
                        from: l.value
                    ),
                    formatNumber(
                        from: u.value
                    )
                )
            )
        } else {
            return nil
        }
    }

    private func temperatureLowerBound() -> CGFloat {
        guard isViewLoaded else { return 0 }
        let (customLowerBound, _) = customTempAlertBound()
        guard let temperatureUnit = viewModel?.temperatureUnit.value
        else {
            let range = TemperatureUnit.celsius.alertRange
            return showCustomTempAlertBound() ? customLowerBound : CGFloat(range.lowerBound)
        }
        if let lower = viewModel?.temperatureLowerBound.value?.converted(to: temperatureUnit.unitTemperature) {
            return CGFloat(lower.value)
        } else {
            return showCustomTempAlertBound() ? customLowerBound : CGFloat(temperatureUnit.alertRange.lowerBound)
        }
    }

    private func temperatureUpperBound() -> CGFloat {
        guard isViewLoaded else { return 0 }
        let (_, customUpperBound) = customTempAlertBound()
        guard let temperatureUnit = viewModel?.temperatureUnit.value
        else {
            let range = TemperatureUnit.celsius.alertRange
            return showCustomTempAlertBound() ? customUpperBound : CGFloat(range.upperBound)
        }
        if let upper = viewModel?.temperatureUpperBound.value?.converted(to: temperatureUnit.unitTemperature) {
            return CGFloat(upper.value)
        } else {
            return showCustomTempAlertBound() ? customUpperBound : CGFloat(temperatureUnit.alertRange.upperBound)
        }
    }

    private func temperatureMinMaxForSliders() -> (minimum: CGFloat, maximum: CGFloat) {
        let tu = viewModel?.temperatureUnit.value ?? .celsius
        let (customLowerBound, customUpperBound) = customTempAlertBound()
        return (
            minimum: CGFloat(
                showCustomTempAlertBound() ? customLowerBound : tu.alertRange.lowerBound
            ),
            maximum: CGFloat(
                showCustomTempAlertBound() ? customUpperBound : tu.alertRange.upperBound
            )
        )
    }

    private func updateTemperatureAlertSlider(for cell: TagSettingsAlertConfigCell) {
        let (minRange, maxRange) = temperatureMinMaxForSliders()
        cell.setAlertLimitDescription(description: temperatureAlertRangeDescription())
        cell.setAlertRange(
            minValue: minRange,
            selectedMinValue: temperatureLowerBound(),
            maxValue: maxRange,
            selectedMaxValue: temperatureUpperBound()
        )
    }

    private func showCustomTempAlertBound() -> Bool {
        viewModel?.showCustomTempAlertBound.value ?? false
    }

    private func customTempAlertBound() -> (lower: Double, upper: Double) {
        let customLowerBound = viewModel?.customTemperatureLowerBound.value?.value ?? -55
        let customUpperBound = viewModel?.customTemperatureUpperBound.value?.value ?? 150
        return (lower: customLowerBound, upper: customUpperBound)
    }

    private func formatNumber(from value: CGFloat?) -> String {
        guard let value = value else { return "" }
        let number = NSNumber(value: Float(value))
        return numberFormatter.string(from: number) ?? ""
    }

    // Humidity
    private func humidityAlertRangeDescription(
        from min: CGFloat? = nil,
        max: CGFloat? = nil
    ) -> NSMutableAttributedString? {
        guard isViewLoaded else { return nil }
        let format = RuuviLocalization.TagSettings.Alerts.description
        if let min, let max {
            return attributedString(
                from: format(
                    formatNumber(
                        from: min
                    ),
                    formatNumber(
                        from: max
                    )
                )
            )
        }
        if let l = viewModel?.relativeHumidityLowerBound.value,
           let u = viewModel?.relativeHumidityUpperBound.value {
            return attributedString(
                from: format(
                    formatNumber(
                        from: l
                    ),
                    formatNumber(
                        from: u
                    )
                )
            )
        } else {
            return nil
        }
    }

    private func humidityLowerBound() -> CGFloat {
        guard isViewLoaded else { return 0 }
        let range = HumidityUnit.percent.alertRange
        if let lower = viewModel?.relativeHumidityLowerBound.value {
            return CGFloat(lower)
        } else {
            return CGFloat(range.lowerBound)
        }
    }

    private func humidityUpperBound() -> CGFloat {
        guard isViewLoaded else { return 100 }
        let range = HumidityUnit.percent.alertRange
        if let upper = viewModel?.relativeHumidityUpperBound.value {
            return CGFloat(upper)
        } else {
            return CGFloat(range.upperBound)
        }
    }

    private func humidityMinMaxForSliders() -> (minimum: CGFloat, maximum: CGFloat) {
        let rhRange = HumidityUnit.percent.alertRange
        return (
            minimum: CGFloat(rhRange.lowerBound),
            maximum: CGFloat(rhRange.upperBound)
        )
    }

    // Pressure
    private func pressureAlertRangeDescription(
        from minValue: CGFloat? = nil,
        maxValue: CGFloat? = nil
    ) -> NSMutableAttributedString? {
        guard isViewLoaded else { return nil }
        let format = RuuviLocalization.TagSettings.Alerts.description

        if let minValue, let maxValue {
            return attributedString(
                from: format(
                    formatNumber(
                        from: minValue
                    ),
                    formatNumber(
                        from: maxValue
                    )
                )
            )
        }

        if let pu = viewModel?.pressureUnit.value,
           let lower = viewModel?.pressureLowerBound.value?.converted(to: pu).value,
           let upper = viewModel?.pressureUpperBound.value?.converted(to: pu).value {
            let l = min(
                max(lower, pu.alertRange.lowerBound),
                pu.alertRange.upperBound
            )
            let u = max(
                min(upper, pu.alertRange.upperBound),
                pu.alertRange.lowerBound
            )
            return attributedString(
                from: format(
                    formatNumber(
                        from: l
                    ),
                    formatNumber(
                        from: u
                    )
                )
            )
        } else {
            return nil
        }
    }

    private func pressureLowerBound() -> CGFloat {
        guard isViewLoaded else { return 0 }
        guard let pu = viewModel?.pressureUnit.value
        else {
            let range = UnitPressure.hectopascals.alertRange
            return CGFloat(range.lowerBound)
        }
        if let lower = viewModel?.pressureLowerBound.value?.converted(to: pu).value {
            let l = min(
                max(lower, pu.alertRange.lowerBound),
                pu.alertRange.upperBound
            )
            return CGFloat(l)
        } else {
            return CGFloat(pu.alertRange.lowerBound)
        }
    }

    private func pressureUpperBound() -> CGFloat {
        guard isViewLoaded else { return 0 }
        guard let pu = viewModel?.pressureUnit.value
        else {
            let range = UnitPressure.hectopascals.alertRange
            return CGFloat(range.upperBound)
        }
        if let upper = viewModel?.pressureUpperBound.value?.converted(to: pu).value {
            let u = max(
                min(upper, pu.alertRange.upperBound),
                pu.alertRange.lowerBound
            )
            return CGFloat(u)
        } else {
            return CGFloat(pu.alertRange.upperBound)
        }
    }

    private func pressureMinMaxForSliders() -> (minimum: CGFloat, maximum: CGFloat) {
        let p = viewModel?.pressureUnit.value ?? .hectopascals
        return (
            minimum: CGFloat(p.alertRange.lowerBound),
            maximum: CGFloat(p.alertRange.upperBound)
        )
    }

    // RSSI
    private func rssiAlertRangeDescription(
        from min: CGFloat? = nil,
        max: CGFloat? = nil
    ) -> NSMutableAttributedString? {
        guard isViewLoaded else { return nil }
        let format = RuuviLocalization.TagSettings.Alerts.description

        if let min, let max {
            return attributedString(
                from: format(
                    formatNumber(
                        from: min
                    ),
                    formatNumber(
                        from: max
                    )
                )
            )
        }

        if let lower = viewModel?.signalLowerBound.value,
           let upper = viewModel?.signalUpperBound.value {
            return attributedString(
                from: format(
                    formatNumber(
                        from: lower
                    ),
                    formatNumber(
                        from: upper
                    )
                )
            )
        } else {
            return nil
        }
    }

    private func rssiLowerBound() -> CGFloat {
        guard isViewLoaded else { return -105 }
        let (minRange, _) = rssiMinMaxForSliders()
        if let lower = viewModel?.signalLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func rssiUpperBound() -> CGFloat {
        guard isViewLoaded else { return 0 }
        let (_, maxRange) = rssiMinMaxForSliders()
        if let upper = viewModel?.signalUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func rssiMinMaxForSliders() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: CGFloat(-105),
            maximum: CGFloat(0)
        )
    }

    private func attributedString(from message: String?) -> NSMutableAttributedString? {
        if let message {
            let attributedString = NSMutableAttributedString(string: message)
            let boldFont = UIFont.Muli(.bold, size: 14)
            let numberRegex = try? NSRegularExpression(pattern: "\\d+([.,]\\d+)?")
            let range = NSRange(location: 0, length: message.utf16.count)
            if let matches = numberRegex?.matches(in: message, options: [], range: range) {
                for match in matches {
                    attributedString.addAttribute(.font, value: boldFont, range: match.range)
                }
            }
            return attributedString
        } else {
            return nil
        }
    }

    // Cloud Connection
    private func cloudConnectionAlertVisible() -> Bool {
        viewModel?.isCloudConnectionAlertsAvailable.value ?? false
    }

    private func cloudConnectionAlertRangeDescription(
        from delay: Int? = nil
    ) -> NSMutableAttributedString? {
        guard isViewLoaded else { return nil }
        if let delay {
            return attributedString(from: RuuviLocalization.alertCloudConnectionDescription(delay))
        } else {
            return nil
        }
    }

    private func cloudConnectionMinUnseenDuration() -> Int {
        2 // mins
    }

    private func cloudConnectionDefaultUnseenDuration() -> Int {
        15 // mins
    }
}

extension TagSettingsViewController: TagSettingsAlertConfigCellDelegate {
    func didSelectSetCustomDescription(sender: TagSettingsAlertConfigCell) {
        var description: String?
        switch sender {
        case temperatureAlertCell:
            description = viewModel?.temperatureAlertDescription.value
        case humidityAlertCell:
            description = viewModel?.relativeHumidityAlertDescription.value
        case pressureAlertCell:
            description = viewModel?.pressureAlertDescription.value
        case rssiAlertCell:
            description = viewModel?.signalAlertDescription.value
        case movementAlertCell:
            description = viewModel?.movementAlertDescription.value
        case connectionAlertCell:
            description = viewModel?.connectionAlertDescription.value
        case cloudConnectionAlertCell:
            description = viewModel?.cloudConnectionAlertDescription.value
        default:
            break
        }

        showSensorCustomAlertDescriptionDialog(
            description: description,
            sender: sender
        )
    }

    func didSelectAlertLimitDescription(sender: TagSettingsAlertConfigCell) {
        switch sender {
        case temperatureAlertCell:
            showTemperatureAlertSetPopup(sender: sender)
        case humidityAlertCell:
            showHumidityAlertSetDialog(sender: sender)
        case pressureAlertCell:
            showPressureAlertSetDialog(sender: sender)
        case rssiAlertCell:
            showRSSIAlertSetDialog(sender: sender)
        case cloudConnectionAlertCell:
            showCloudConnectionAlertSetDialog(sender: sender)
        default:
            break
        }
    }

    func didChangeAlertState(sender: TagSettingsAlertConfigCell, didToggle isOn: Bool) {
        switch sender {
        case temperatureAlertCell:
            output.viewDidChangeAlertState(
                for: .temperature(lower: 0, upper: 0),
                isOn: isOn
            )

        case humidityAlertCell:
            output.viewDidChangeAlertState(
                for: .relativeHumidity(lower: 0, upper: 0),
                isOn: isOn
            )

        case pressureAlertCell:
            output.viewDidChangeAlertState(
                for: .pressure(lower: 0, upper: 0),
                isOn: isOn
            )

        case rssiAlertCell:
            output.viewDidChangeAlertState(
                for: .signal(lower: 0, upper: 0),
                isOn: isOn
            )

        case movementAlertCell:
            output.viewDidChangeAlertState(
                for: .movement(last: 0),
                isOn: isOn
            )

        case connectionAlertCell:
            output.viewDidChangeAlertState(
                for: .connection,
                isOn: isOn
            )

        case cloudConnectionAlertCell:
            output.viewDidChangeAlertState(
                for: .cloudConnection(unseenDuration: 0),
                isOn: isOn
            )

        default:
            break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func didSetAlertRange(
        sender: TagSettingsAlertConfigCell,
        minValue: CGFloat,
        maxValue: CGFloat
    ) {
        guard minValue < maxValue else { return }
        switch sender {
        case temperatureAlertCell:
            if minValue != viewModel?.temperatureLowerBound.value?.value {
                output.viewDidChangeAlertLowerBound(
                    for: .temperature(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.temperatureUpperBound.value?.value {
                output.viewDidChangeAlertUpperBound(
                    for: .temperature(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case humidityAlertCell:
            if minValue != viewModel?.relativeHumidityLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .relativeHumidity(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.relativeHumidityUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .relativeHumidity(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case pressureAlertCell:
            if minValue != viewModel?.pressureLowerBound.value?.value {
                output.viewDidChangeAlertLowerBound(
                    for: .pressure(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.pressureUpperBound.value?.value {
                output.viewDidChangeAlertUpperBound(
                    for: .pressure(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case rssiAlertCell:
            if minValue != viewModel?.signalLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .signal(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.signalUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .signal(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        default:
            break
        }
    }

    func didChangeAlertRange(
        sender: TagSettingsAlertConfigCell,
        didSlideTo minValue: CGFloat,
        maxValue: CGFloat
    ) {
        switch sender {
        case temperatureAlertCell:
            temperatureAlertCell?.setAlertLimitDescription(
                description: temperatureAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case humidityAlertCell:
            humidityAlertCell?.setAlertLimitDescription(
                description: humidityAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case pressureAlertCell:
            pressureAlertCell?.setAlertLimitDescription(
                description: pressureAlertRangeDescription(
                    from: minValue,
                    maxValue: maxValue
                ))
        case rssiAlertCell:
            rssiAlertCell?.setAlertLimitDescription(
                description: rssiAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        default:
            break
        }
    }
}

// MARK: - SET CUSTOM ALERT RANGE POPUP

extension TagSettingsViewController {
    private func showTemperatureAlertSetPopup(sender: TagSettingsAlertConfigCell) {
        let temperatureUnit = viewModel?.temperatureUnit.value ?? .celsius
        let titleFormat = RuuviLocalization.TagSettings.Alert.SetTemperature.title
        let title = titleFormat + " (\(temperatureUnit.symbol))"

        let (minimumRange, maximumRange) = temperatureAlertRange()
        let (minimumValue, maximumValue) = temperatureValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showHumidityAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let symbol = HumidityUnit.percent.symbol
        let titleFormat = RuuviLocalization.TagSettings.Alert.SetHumidity.title
        let title = titleFormat + " (\(symbol))"

        let (minimumRange, maximumRange) = humidityAlertRange()
        let (minimumValue, maximumValue) = humidityValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showPressureAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let pressureUnit = viewModel?.pressureUnit.value ?? .hectopascals
        let titleFormat = RuuviLocalization.TagSettings.Alert.SetPressure.title
        let title = titleFormat + " (\(pressureUnit.symbol))"

        let (minimumRange, maximumRange) = pressureAlertRange()
        let (minimumValue, maximumValue) = pressureValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showRSSIAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let symbol = RuuviLocalization.dBm
        let titleFormat = RuuviLocalization.TagSettings.Alert.SetRSSI.title
        let title = titleFormat + " (\(symbol))"

        let (minimumRange, maximumRange) = rssiAlertRange()
        let (minimumValue, maximumValue) = rssiValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showCloudConnectionAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.alertCloudConnectionDialogTitle
        let message = RuuviLocalization.alertCloudConnectionDialogDescription

        let minimumDuration = cloudConnectionMinUnseenDuration()
        let defaultDuration = cloudConnectionDefaultUnseenDuration()
        let currentDuration = viewModel?.cloudConnectionAlertUnseenDuration.value?.intValue ?? 900

        showSensorCustomAlertRangeDialog(
            title: title,
            message: message,
            minimum: minimumDuration,
            default: defaultDuration,
            current: currentDuration / 60,
            sender: sender
        )
    }

    private func temperatureAlertRange() -> (minimum: Double, maximum: Double) {
        let unit = viewModel?.temperatureUnit.value?.unitTemperature ?? .celsius
        guard let customLowerBound = viewModel?.customTemperatureLowerBound.value?.converted(to: unit),
              let customUpperBound = viewModel?.customTemperatureUpperBound.value?.converted(to: unit) else {
            let temperatureUnit = viewModel?.temperatureUnit.value ?? .celsius
            return (
                minimum: temperatureUnit.alertRange.lowerBound,
                maximum: temperatureUnit.alertRange.upperBound
            )
        }
        return (
            minimum: customLowerBound.value,
            maximum: customUpperBound.value
        )
    }

    private func temperatureValue() -> (minimum: Double?, maximum: Double?) {
        if let unit = viewModel?.temperatureUnit.value?.unitTemperature,
           let l = viewModel?.temperatureLowerBound.value?.converted(to: unit),
           let u = viewModel?.temperatureUpperBound.value?.converted(to: unit) {
            (
                minimum: l.value,
                maximum: u.value
            )
        } else {
            (
                minimum: nil,
                maximum: nil
            )
        }
    }

    private func humidityAlertRange() -> (minimum: Double, maximum: Double) {
        let range = HumidityUnit.percent.alertRange
        return (minimum: range.lowerBound, maximum: range.upperBound)
    }

    private func humidityValue() -> (minimum: Double?, maximum: Double?) {
        if let l = viewModel?.relativeHumidityLowerBound.value,
           let u = viewModel?.relativeHumidityUpperBound.value {
            (minimum: l, maximum: u)
        } else {
            (minimum: nil, maximum: nil)
        }
    }

    private func pressureAlertRange() -> (minimum: Double, maximum: Double) {
        let pressureUnit = viewModel?.pressureUnit.value ?? .hectopascals
        return (
            minimum: pressureUnit.alertRange.lowerBound,
            maximum: pressureUnit.alertRange.upperBound
        )
    }

    private func pressureValue() -> (minimum: Double?, maximum: Double?) {
        let (minimumRange, maximumRange) = pressureAlertRange()
        if let pressureUnit = viewModel?.pressureUnit.value,
           let lower = viewModel?.pressureLowerBound.value?.converted(to: pressureUnit).value,
           let upper = viewModel?.pressureUpperBound.value?.converted(to: pressureUnit).value {
            let l = min(
                max(lower, minimumRange),
                maximumRange
            )
            let u = max(
                min(upper, maximumRange),
                minimumRange
            )
            return (minimum: l, maximum: u)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // TODO: - Move the values to a separate constant file
    private func rssiAlertRange() -> (minimum: Double, maximum: Double) {
        (
            minimum: -105,
            maximum: 0
        )
    }

    private func rssiValue() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.signalLowerBound.value,
           let upper = viewModel?.signalUpperBound.value {
            (minimum: lower, maximum: upper)
        } else {
            (minimum: nil, maximum: nil)
        }
    }
}

// MARK: - OFFSET CORRECTION SECTION

extension TagSettingsViewController {
    // swiftlint:disable:next function_body_length
    private func bindOffsetCorrectionSection() {
        guard let viewModel
        else {
            return
        }

        tableView.bind(viewModel.isNetworkConnected) { [weak self] _, _ in
            self?.reloadSection(identifier: .offsetCorrection)
        }

        tableView.bind(viewModel.isOwner) { [weak self] _, _ in
            self?.reloadSection(identifier: .offsetCorrection)
        }

        if let tempOffsetCorrectionCell {
            tempOffsetCorrectionCell.bind(viewModel
                .temperatureOffsetCorrection) { [weak self] cell, value in
                    cell.configure(value: self?
                        .measurementService
                        .temperatureOffsetCorrectionString(for: value ?? 0))
                }

            tempOffsetCorrectionCell.bind(viewModel.latestMeasurement) { cell, measurement in
                cell.disableEditing(measurement == nil)
            }
        }

        if let humidityOffsetCorrectionCell {
            humidityOffsetCorrectionCell
                .bind(viewModel.humidityOffsetCorrection) { [weak self] cell, value in
                    cell.configure(value: self?
                        .measurementService
                        .humidityOffsetCorrectionString(for: value ?? 0))
                }

            humidityOffsetCorrectionCell.bind(viewModel.latestMeasurement) {
                [weak self] cell, measurement in
                guard let sSelf = self else { return }
                cell.disableEditing(measurement == nil ||
                    !sSelf.showHumidityOffsetCorrection())
            }

            humidityOffsetCorrectionCell.bind(viewModel
                .humidityOffsetCorrectionVisible) { cell, visible in
                    cell.disableEditing(!GlobalHelpers.getBool(from: visible))
                }
        }

        if let pressureOffsetCorrectionCell {
            pressureOffsetCorrectionCell.bind(viewModel
                .pressureOffsetCorrection) { [weak self] cell, value in
                    cell.configure(value: self?
                        .measurementService
                        .pressureOffsetCorrectionString(for: value ?? 0))
                }

            pressureOffsetCorrectionCell.bind(viewModel
                .pressureOffsetCorrectionVisible) { cell, visible in
                    cell.disableEditing(!GlobalHelpers.getBool(from: visible))
                }

            pressureOffsetCorrectionCell.bind(viewModel.latestMeasurement) {
                [weak self] cell, measurement in
                guard let sSelf = self else { return }
                cell.disableEditing(measurement == nil ||
                    !sSelf.showPressureOffsetCorrection())
            }
        }
    }

    private func configureOffsetCorrectionSection() -> TagSettingsSection {
        let offsetCorrectionItems: [TagSettingsItem] = [
            offsetCorrectionTemperatureItem(),
            offsetCorrectionHumidityItem(),
            offsetCorrectionPressureItem(),
        ]

        let section = TagSettingsSection(
            identifier: .offsetCorrection,
            title: RuuviLocalization.TagSettings.SectionHeader.OffsetCorrection.title.capitalized,
            cells: offsetCorrectionItems,
            collapsed: true,
            headerType: .expandable,
            backgroundColor: RuuviColor.tagSettingsSectionHeaderColor.color,
            font: UIFont.Muli(.bold, size: 18)
        )
        return section
    }

    private func offsetCorrectionTemperatureItem() -> TagSettingsItem {
        let tempOffset = viewModel?.temperatureOffsetCorrection.value ?? 0
        let hasMeasurement = hasMeasurement()
        let settingItem = TagSettingsItem(
            identifier: .offsetTemperature,
            createdCell: { [weak self] in
                self?.tempOffsetCorrectionCell?.configure(
                    title: RuuviLocalization.TagSettings.OffsetCorrection.temperature,
                    value: self?.measurementService
                        .temperatureOffsetCorrectionString(for: tempOffset)
                )
                self?.tempOffsetCorrectionCell?.setAccessory(type: .chevron)
                self?.tempOffsetCorrectionCell?.disableEditing(!hasMeasurement)
                return self?.tempOffsetCorrectionCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                guard hasMeasurement else { return }
                self?.output.viewDidTapTemperatureOffsetCorrection()
            }
        )
        return settingItem
    }

    private func offsetCorrectionHumidityItem() -> TagSettingsItem {
        let humOffset = viewModel?.humidityOffsetCorrection.value ?? 0
        let disableHumidity = !hasMeasurement() || !showHumidityOffsetCorrection()
        let settingItem = TagSettingsItem(
            identifier: .offsetHumidity,
            createdCell: { [weak self] in
                self?
                    .humidityOffsetCorrectionCell?
                    .configure(
                        title: RuuviLocalization.TagSettings.OffsetCorrection.humidity,
                        value: self?.measurementService
                            .humidityOffsetCorrectionString(for: humOffset)
                    )
                self?.humidityOffsetCorrectionCell?.setAccessory(type: .chevron)
                self?.humidityOffsetCorrectionCell?.disableEditing(disableHumidity)
                return self?.humidityOffsetCorrectionCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                guard !disableHumidity
                else {
                    return
                }
                self?.output.viewDidTapHumidityOffsetCorrection()
            }
        )
        return settingItem
    }

    private func offsetCorrectionPressureItem() -> TagSettingsItem {
        let pressureOffset = viewModel?.pressureOffsetCorrection.value ?? 0
        let disablePressure = !hasMeasurement() || !showPressureOffsetCorrection()
        let settingItem = TagSettingsItem(
            identifier: .offsetPressure,
            createdCell: { [weak self] in
                self?
                    .pressureOffsetCorrectionCell?
                    .configure(
                        title: RuuviLocalization.TagSettings.OffsetCorrection.pressure,
                        value: self?.measurementService.pressureOffsetCorrectionString(for: pressureOffset)
                    )
                self?.pressureOffsetCorrectionCell?.setAccessory(type: .chevron)
                self?.pressureOffsetCorrectionCell?.hideSeparator(hide: true)
                self?.pressureOffsetCorrectionCell?.disableEditing(disablePressure)
                return self?.pressureOffsetCorrectionCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                guard !disablePressure
                else {
                    return
                }
                self?.output.viewDidTapOnPressureOffsetCorrection()
            }
        )
        return settingItem
    }

    // Offset correction helpers
    private func showOffsetCorrection() -> Bool {
        let isOwner = GlobalHelpers.getBool(
            from: viewModel?.isOwner.value
        )
        let isNetworkConnected = GlobalHelpers.getBool(
            from: viewModel?.isNetworkConnected.value
        )

        return !(isNetworkConnected && !isOwner)
    }

    private func showHumidityOffsetCorrection() -> Bool {
        viewModel?.humidityOffsetCorrectionVisible.value == true
    }

    private func showPressureOffsetCorrection() -> Bool {
        viewModel?.pressureOffsetCorrectionVisible.value == true
    }

    private func showOnlyTemperatureOffsetCorrection() -> Bool {
        !showHumidityOffsetCorrection() && !showPressureOffsetCorrection()
    }

    /// Returns True if viewModel has measurement
    private func hasMeasurement() -> Bool {
        GlobalHelpers.getBool(from: viewModel?.latestMeasurement.value != nil)
    }
}

// MARK: - MORE INFO SECTION

extension TagSettingsViewController {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func bindMoreInfoSection() {
        guard let viewModel
        else {
            return
        }

        let emptyString = RuuviLocalization.na

        // Mac address
        if let moreInfoMacAddressCell {
            moreInfoMacAddressCell.bind(viewModel.mac) { cell, mac in
                cell.configure(value: mac ?? emptyString)
            }
        }

        // Data format
        if let moreInfoDataFormatCell {
            moreInfoDataFormatCell.bind(viewModel.version) { cell, version in
                cell.configure(value: version.stringValue)
            }
        }

        // Data source
        if let moreInfoDataSourceCell {
            moreInfoDataSourceCell.bind(viewModel.source) { [weak self] cell, source in
                cell.configure(value: self?.formattedDataSource(from: source))
            }
        }

        // Voltage cell
        if let moreInfoBatteryVoltageCell {
            moreInfoBatteryVoltageCell.bind(viewModel.voltage) { [weak self] cell, voltage in
                cell.configure(value: self?.formattedBatteryVoltage(from: voltage))
            }

            moreInfoBatteryVoltageCell.bind(viewModel.batteryNeedsReplacement) { [weak self]
                cell, needsReplacement in
                guard let sSelf = self else { return }
                let (status, color) = sSelf.formattedBatteryStatus(from: needsReplacement)
                cell.configure(note: status, noteColor: color)
            }
        }

        // Acceleration X
        if let moreInfoAccXCell {
            moreInfoAccXCell.bind(viewModel.accelerationX) {
                [weak self] cell, accelerationX in
                cell.configure(value: self?
                    .formattedAccelerationValue(from: accelerationX))
            }
        }

        // Acceleration Y
        if let moreInfoAccYCell {
            moreInfoAccYCell.bind(viewModel.accelerationY) {
                [weak self] cell, accelerationY in
                cell.configure(value: self?
                    .formattedAccelerationValue(from: accelerationY))
            }
        }

        // Acceleration Z
        if let moreInfoAccZCell {
            moreInfoAccZCell.bind(viewModel.accelerationZ) {
                [weak self] cell, accelerationZ in
                cell.configure(value: self?
                    .formattedAccelerationValue(from: accelerationZ))
            }
        }

        // TX power
        if let moreInfoTxPowerCell {
            moreInfoTxPowerCell.bind(viewModel.txPower) {
                [weak self] cell, txPower in
                cell.configure(value: self?.formattedTXPower(from: txPower))
            }
        }

        // RSSI
        if let moreInfoRSSICell {
            moreInfoRSSICell.bind(viewModel.rssi) { cell, rssi in
                cell.configure(value: rssi?.stringValue)
            }
        }

        // MSN
        if let moreInfoMSNCell {
            moreInfoMSNCell.bind(viewModel.measurementSequenceNumber) { cell, msn in
                cell.configure(value: msn.stringValue)
            }
        }

        // Header
        if let moreInfoSectionHeaderView {
            moreInfoSectionHeaderView.bind(viewModel.version) { header, value
                in
                guard let value else { return }
                header.showNoValueView(
                    show: GlobalHelpers.getBool(from: value < 5))
            }
        }
    }

    private func configureMoreInfoSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .moreInfo,
            title: RuuviLocalization.TagSettings.Label.MoreInfo.text.capitalized,
            cells: [
                moreInfoMacAddressItem(),
                moreInfoDataFormatItem(),
                moreInfoDataSourceItem(),
                moreInfoBatteryVoltageItem(),
                moreInfoAccXItem(),
                moreInfoAccYItem(),
                moreInfoAccZItem(),
                moreInfoTxPowerItem(),
                moreInfoRSSIItem(),
                moreInfoMeasurementSequenceItem(),
            ],
            collapsed: true,
            headerType: .expandable,
            backgroundColor: RuuviColor.tagSettingsSectionHeaderColor.color,
            font: UIFont.Muli(.bold, size: 18)
        )
        return section
    }

    private func moreInfoMacAddressItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoMacAddressCell?.configure(
                    title: RuuviLocalization.TagSettings.MacAddressTitleLabel.text,
                    value: self?.viewModel?.mac.value ?? RuuviLocalization.na
                )
                return self?.moreInfoMacAddressCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                self?.output.viewDidTapOnMacAddress()
            }
        )
        return settingItem
    }

    private func moreInfoDataFormatItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoDataFormatCell?.configure(
                    title: RuuviLocalization.TagSettings.DataFormatTitleLabel.text,
                    value: self?.viewModel?.version.value?.stringValue
                )
                self?.moreInfoDataFormatCell?.selectionStyle = .none
                return self?.moreInfoDataFormatCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoDataSourceItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoDataSourceCell?.configure(
                    title: RuuviLocalization.TagSettings.DataSourceTitleLabel.text,
                    value: self?.formattedDataSource(from: self?.viewModel?.source.value)
                )
                self?.moreInfoDataSourceCell?.selectionStyle = .none
                return self?.moreInfoDataSourceCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoBatteryVoltageItem() -> TagSettingsItem {
        let (status, color) = formattedBatteryStatus(from: viewModel?.batteryNeedsReplacement.value)
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoBatteryVoltageCell?.configure(
                    title: RuuviLocalization.TagSettings.BatteryVoltageTitleLabel.text,
                    value: self?.formattedBatteryVoltage(from: self?.viewModel?.voltage.value),
                    note: status,
                    noteColor: color
                )
                self?.moreInfoBatteryVoltageCell?.selectionStyle = .none
                return self?.moreInfoBatteryVoltageCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoAccXItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoAccXCell?.configure(
                    title: RuuviLocalization.TagSettings.AccelerationXTitleLabel.text,
                    value: self?.formattedAccelerationValue(from: self?.viewModel?.accelerationX.value)
                )
                self?.moreInfoAccXCell?.selectionStyle = .none
                return self?.moreInfoAccXCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoAccYItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoAccYCell?.configure(
                    title: RuuviLocalization.TagSettings.AccelerationYTitleLabel.text,
                    value: self?.formattedAccelerationValue(from: self?.viewModel?.accelerationY.value)
                )
                self?.moreInfoAccYCell?.selectionStyle = .none
                return self?.moreInfoAccYCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoAccZItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoAccZCell?.configure(
                    title: RuuviLocalization.TagSettings.AccelerationZTitleLabel.text,
                    value: self?.formattedAccelerationValue(from: self?.viewModel?.accelerationZ.value)
                )
                self?.moreInfoAccZCell?.selectionStyle = .none
                return self?.moreInfoAccZCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoTxPowerItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoTxPowerCell?.configure(
                    title: RuuviLocalization.TagSettings.TxPowerTitleLabel.text,
                    value: self?.formattedTXPower(from: self?.viewModel?.txPower.value)
                )
                self?.moreInfoTxPowerCell?.selectionStyle = .none
                return self?.moreInfoTxPowerCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func moreInfoRSSIItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoRSSICell?.configure(
                    title: RuuviLocalization.TagSettings.RssiTitleLabel.text,
                    value: self?.viewModel?.rssi.value.stringValue
                )
                return self?.moreInfoRSSICell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                self?.output.viewDidTapOnTxPower()
            }
        )
        return settingItem
    }

    private func moreInfoMeasurementSequenceItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoMSNCell?.configure(
                    title: RuuviLocalization.TagSettings.MsnTitleLabel.text,
                    value: self?.viewModel?.measurementSequenceNumber.value.stringValue
                )
                return self?.moreInfoMSNCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                self?.output.viewDidTapOnMeasurementSequenceNumber()
            }
        )
        return settingItem
    }

    // More Info Helpers
    private func formattedDataSource(from source: RuuviTagSensorRecordSource?) -> String {
        let emptyString = RuuviLocalization.na

        if let source {
            var sourceString = emptyString
            switch source {
            case .advertisement:
                sourceString = RuuviLocalization.TagSettings.DataSource.Advertisement.title
            case .heartbeat:
                sourceString = RuuviLocalization.TagSettings.DataSource.Heartbeat.title
            case .log:
                sourceString = RuuviLocalization.TagSettings.DataSource.Heartbeat.title
            case .ruuviNetwork:
                sourceString = RuuviLocalization.TagSettings.DataSource.Network.title
            default:
                sourceString = emptyString
            }
            return sourceString
        } else {
            return emptyString
        }
    }

    private func formattedBatteryVoltage(from value: Double?) -> String {
        if let value {
            String.localizedStringWithFormat("%.3f", value) + " " + RuuviLocalization.v
        } else {
            RuuviLocalization.na
        }
    }

    private func formattedBatteryStatus(from batteryLow: Bool?) -> (status: String?, color: UIColor?) {
        if let batteryLow {
            // swiftlint:disable:next line_length
            let batteryStatus = batteryLow ? "(\(RuuviLocalization.TagSettings.BatteryStatusLabel.Replace.message))" : "(\(RuuviLocalization.TagSettings.BatteryStatusLabel.Ok.message))"
            let indicatorColor = batteryLow ? RuuviColor.orangeColor.color : RuuviColor.tintColor.color
            return (status: batteryStatus, color: indicatorColor)
        } else {
            return (status: nil, color: nil)
        }
    }

    private func formattedAccelerationValue(from value: Double?) -> String {
        if let value {
            String.localizedStringWithFormat("%.3f", value) + " " + RuuviLocalization.g
        } else {
            RuuviLocalization.na
        }
    }

    private func formattedTXPower(from value: Int?) -> String {
        if let value {
            value.stringValue + " " + RuuviLocalization.dBm
        } else {
            RuuviLocalization.na
        }
    }
}

// MARK: - FIRMWARE SECTION

extension TagSettingsViewController {
    private func bindFirmwareSection() {
        guard let viewModel
        else {
            return
        }

        if let firmwareVersionCell {
            firmwareVersionCell.bind(viewModel.firmwareVersion) { cell, value in
                cell.configure(value: value ?? RuuviLocalization.na)
            }
        }
    }

    private func configureFirmwareSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .firmware,
            title: RuuviLocalization.TagSettings.SectionHeader.Firmware.title.capitalized,
            cells: [
                tagFirmwareVersionItem(),
                tagFirmwareUpdateItem(),
            ],
            collapsed: true,
            headerType: .expandable,
            backgroundColor: RuuviColor.tagSettingsSectionHeaderColor.color,
            font: UIFont.Muli(.bold, size: 18)
        )
        return section
    }

    private func tagFirmwareVersionItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.firmwareVersionCell?.configure(
                    title: RuuviLocalization.TagSettings.Firmware.currentVersion,
                    value: self?.viewModel?.firmwareVersion.value ?? RuuviLocalization.na
                )
                self?.firmwareVersionCell?.setAccessory(type: .none)
                self?.firmwareVersionCell?.selectionStyle = .none
                return self?.firmwareVersionCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    private func tagFirmwareUpdateItem() -> TagSettingsItem {
        let cell = TagSettingsBasicCell(style: .value1, reuseIdentifier: Self.ReuseIdentifier)
        let settingItem = TagSettingsItem(
            createdCell: {
                cell.configure(
                    title: RuuviLocalization.TagSettings.Firmware.updateFirmware,
                    value: nil
                )
                cell.setAccessory(type: .chevron)
                cell.hideSeparator(hide: true)
                return cell
            },
            action: { [weak self] _ in
                self?.output.viewDidTapOnUpdateFirmware()
            }
        )
        return settingItem
    }
}

// MARK: - REMOVE SECTION

extension TagSettingsViewController {
    private func configureRemoveSection() -> TagSettingsSection {
        let section = TagSettingsSection(
            identifier: .remove,
            title: RuuviLocalization.remove.capitalized,
            cells: [
                tagRemoveItem()
            ],
            collapsed: true,
            headerType: .expandable,
            backgroundColor: RuuviColor.tagSettingsSectionHeaderColor.color,
            font: UIFont.Muli(.bold, size: 18)
        )
        return section
    }

    private func tagRemoveItem() -> TagSettingsItem {
        let cell = TagSettingsBasicCell(style: .value1, reuseIdentifier: Self.ReuseIdentifier)
        let settingItem = TagSettingsItem(
            createdCell: {
                cell.configure(title: RuuviLocalization.TagSettings.RemoveThisSensor.title, value: nil)
                cell.setAccessory(type: .chevron)
                cell.hideSeparator(hide: true)
                return cell
            },
            action: { [weak self] _ in
                self?.output.viewDidAskToRemoveRuuviTag()
            }
        )
        return settingItem
    }
}

// MARK: - TableView delegate and datasource

extension TagSettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(
        _: UITableView,
        numberOfRowsInSection section: Int
    ) -> Int {
        tableViewSections[section].collapsed ? 0 : tableViewSections[section].cells.count
    }

    func tableView(
        _: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableViewSections[indexPath.section].cells[indexPath.row]
        return cell.createdCell()
    }

    func numberOfSections(in _: UITableView) -> Int {
        tableViewSections.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let cell = tableViewSections[indexPath.section].cells[indexPath.row]
        cell.action?(cell)
    }

    func tableView(_: UITableView, heightForHeaderInSection _: Int) -> CGFloat {
        48
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func tableView(
        _: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let sectionItem = tableViewSections[section]
        switch sectionItem.headerType {
        case .simple:
            let view = TagSettingsSimpleSectionHeader()
            view.setTitle(
                with: sectionItem.title,
                section: section
            )
            return view
        case .expandable:

            switch sectionItem.identifier {
            case .alertTemperature:
                return alertSectionHeaderView(
                    from: temperatureAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.temperatureAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isTemperatureAlertOn.value
                    ),
                    alertState: viewModel?.temperatureAlertState.value,
                    section: section
                )
            case .alertHumidity:
                return alertSectionHeaderView(
                    from: humidityAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.relativeHumidityAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isRelativeHumidityAlertOn.value
                    ),
                    alertState: viewModel?.relativeHumidityAlertState.value,
                    section: section
                )
            case .alertPressure:
                return alertSectionHeaderView(
                    from: pressureAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.pressureAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isPressureAlertOn.value
                    ),
                    alertState: viewModel?.pressureAlertState.value,
                    section: section
                )
            case .alertRSSI:
                return alertSectionHeaderView(
                    from: rssiAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.signalAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isSignalAlertOn.value
                    ),
                    alertState: viewModel?.signalAlertState.value,
                    section: section
                )
            case .alertMovement:
                return alertSectionHeaderView(
                    from: movementAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.movementAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isMovementAlertOn.value
                    ),
                    alertState: viewModel?.movementAlertState.value,
                    section: section
                )
            case .alertConnection:
                return alertSectionHeaderView(
                    from: connectionAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.connectionAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isConnectionAlertOn.value
                    ),
                    alertState: viewModel?.connectionAlertState.value,
                    section: section
                )
            case .alertCloudConnection:
                return alertSectionHeaderView(
                    from: cloudConnectionAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.cloudConnectionAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isCloudConnectionAlertOn.value
                    ),
                    alertState: viewModel?.cloudConnectionAlertState.value,
                    section: section
                )
            case .moreInfo:
                moreInfoSectionHeaderView?.delegate = self
                moreInfoSectionHeaderView?.setTitle(
                    with: sectionItem.title,
                    section: section,
                    collapsed: sectionItem.collapsed,
                    backgroundColor: sectionItem.backgroundColor,
                    font: sectionItem.font
                )
                moreInfoSectionHeaderView?
                    .hideSeparator(hide: tableViewSections.count == section)
                moreInfoSectionHeaderView?.hideAlertComponents()
                if let version = viewModel?.version.value {
                    moreInfoSectionHeaderView?.showNoValueView(
                        show: GlobalHelpers
                            .getBool(from: version < 5))
                } else {
                    moreInfoSectionHeaderView?.showNoValueView(
                        show: false)
                }
                return moreInfoSectionHeaderView ??
                    TagSettingsExpandableSectionHeader() // Should never be here
            default:
                let view = TagSettingsExpandableSectionHeader()
                view.delegate = self
                view.setTitle(
                    with: sectionItem.title,
                    section: section,
                    collapsed: sectionItem.collapsed,
                    backgroundColor: sectionItem.backgroundColor,
                    font: sectionItem.font
                )
                view.hideSeparator(hide: tableViewSections.count == section)
                view.hideAlertComponents()
                view.showNoValueView(show: false)
                return view
            }
        }
    }

    // swiftlint:disable:next function_parameter_count
    private func alertSectionHeaderView(
        from header: TagSettingsExpandableSectionHeader?,
        sectionItem: TagSettingsSection,
        mutedTill: Date?,
        isAlertOn: Bool,
        alertState: AlertState?,
        section: Int
    ) -> TagSettingsExpandableSectionHeader {
        if let header {
            header.delegate = self
            header.setTitle(
                with: sectionItem.title,
                section: section,
                collapsed: sectionItem.collapsed,
                backgroundColor: sectionItem.backgroundColor,
                font: sectionItem.font
            )
            header.setAlertState(
                with: mutedTill,
                isOn: isAlertOn,
                alertState: alertState
            )
            header.hideSeparator(hide: tableViewSections.count == section)
            header.showNoValueView(show: false)
            return header
        } else {
            // Should never be here
            return TagSettingsExpandableSectionHeader()
        }
    }
}

//

// MARK: - Section Header Delegate

//
extension TagSettingsViewController: TagSettingsExpandableSectionHeaderDelegate {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func toggleSection(_ header: TagSettingsExpandableSectionHeader, section: Int) {
        let currentSection = tableViewSections[section]
        let collapsed = !currentSection.collapsed
        tableViewSections[section].collapsed = collapsed
        header.setCollapsed(collapsed)
        reloadSection(index: section)

        switch currentSection.identifier {
        case .alertTemperature:
            reloadTemperatureAlertSectionHeader()
        case .alertHumidity:
            reloadRHAlertSectionHeader()
        case .alertPressure:
            reloadPressureAlertSectionHeader()
        case .alertRSSI:
            reloadSignalAlertSectionHeader()
        case .alertMovement:
            reloadMovementAlertSectionHeader()
        case .alertConnection:
            reloadConnectionAlertSectionHeader()
        case .alertCloudConnection:
            reloadCloudConnectionAlertSectionHeader()
        default:
            break
        }

        if !collapsed {
            switch currentSection.identifier {
            case .alertTemperature:
                if let temperatureAlertCell {
                    let (minRange, maxRange) = temperatureMinMaxForSliders()
                    temperatureAlertCell.setAlertLimitDescription(description: temperatureAlertRangeDescription())
                    temperatureAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: temperatureLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: temperatureUpperBound()
                    )
                    temperatureAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(from: !hasMeasurement()),
                        identifier: currentSection.identifier
                    )
                }
            case .alertHumidity:
                if let humidityAlertCell {
                    let (minRange, maxRange) = humidityMinMaxForSliders()
                    humidityAlertCell.setAlertLimitDescription(description: humidityAlertRangeDescription())
                    humidityAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: humidityLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: humidityUpperBound()
                    )
                    humidityAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !showHumidityOffsetCorrection() || !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertPressure:
                if let pressureAlertCell {
                    let (minRange, maxRange) = pressureMinMaxForSliders()
                    pressureAlertCell.setAlertLimitDescription(description: pressureAlertRangeDescription())
                    pressureAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: pressureLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: pressureUpperBound()
                    )
                    pressureAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !showPressureOffsetCorrection() || !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertRSSI:
                if let rssiAlertCell {
                    let (minRange, maxRange) = rssiMinMaxForSliders()
                    rssiAlertCell.setAlertLimitDescription(description: rssiAlertRangeDescription())
                    rssiAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: rssiLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: rssiUpperBound()
                    )
                    rssiAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(from: !hasMeasurement()) ||
                            !GlobalHelpers.getBool(from: viewModel?.isClaimedTag.value),
                        identifier: currentSection.identifier
                    )
                }
            case .alertMovement:
                if let movementAlertCell {
                    movementAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: viewModel?.movementCounter.value == nil || !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertConnection:
                if let connectionAlertCell {
                    connectionAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertCloudConnection:
                break
            case .offsetCorrection:
                if let tempOffsetCorrectionCell {
                    tempOffsetCorrectionCell.disableEditing(!hasMeasurement())
                }

                if let humidityOffsetCorrectionCell {
                    humidityOffsetCorrectionCell.disableEditing(
                        !hasMeasurement() ||
                            !showHumidityOffsetCorrection()
                    )
                }

                if let pressureOffsetCorrectionCell {
                    pressureOffsetCorrectionCell.disableEditing(
                        !hasMeasurement() ||
                            !showPressureOffsetCorrection()
                    )
                }
            default:
                break
            }
        }
    }

    func didTapSectionMoreInfo(headerView _: TagSettingsExpandableSectionHeader) {
        output.viewDidTapOnNoValuesView()
    }
}

private extension TagSettingsViewController {
    // swiftlint:disable:next function_body_length
    func setUpUI() {
        title = RuuviLocalization.TagSettings.NavigationItem.title

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

        let rightBarButtonItemView = UIView()
        rightBarButtonItemView.addSubview(exportButton)
        exportButton.anchor(
            top: rightBarButtonItemView.topAnchor,
            leading: rightBarButtonItemView.leadingAnchor,
            bottom: rightBarButtonItemView.bottomAnchor,
            trailing: rightBarButtonItemView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: -14),
            size: .init(width: 48, height: 48)
        )
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonItemView)

        let container = UIView(color: .clear)
        view.addSubview(container)
        container.anchor(
            top: view.safeTopAnchor,
            leading: view.leadingAnchor,
            bottom: view.bottomAnchor,
            trailing: view.trailingAnchor
        )

        container.addSubview(tableView)
        tableView.fillSuperview()

        let tableHeaderView = UIView(color: .clear)
        tableHeaderView.frame = CGRect(
            x: 0,
            y: 0,
            width: view.bounds.width,
            height: GlobalHelpers.isDeviceTablet() ? 350 : 200
        )
        tableHeaderView.addSubview(headerContentView)
        headerContentView.fillSuperview()
        headerContentView.delegate = self

        tableView.tableHeaderView = tableHeaderView
        tableView.tableFooterView = UIView(frame: CGRect.zero)
        tableView.cellLayoutMarginsFollowReadableWidth = true
        if #available(iOS 15.0, *) {
            tableView.sectionHeaderTopPadding = 0
        }
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 50
    }
}

private extension TagSettingsViewController {
    @objc func backButtonDidTap() {
        output.viewDidAskToDismiss()
    }

    @objc func exportButtonDidTap() {
        output.viewDidTapOnExport()
    }
}

extension TagSettingsViewController: TagSettingsBackgroundSelectionViewDelegate {
    func didTapChangeBackground() {
        output.viewDidTriggerChangeBackground()
    }
}

// MARK: - Sensor name rename dialog

extension TagSettingsViewController {
    private func showSensorNameRenameDialog(
        name: String?,
        sortingType: DashboardSortingType
    ) {
        let defaultName = GlobalHelpers.ruuviTagDefaultName(
            from: viewModel?.mac.value,
            luid: viewModel?.uuid.value
        )
        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
            message: sortingType == .alphabetical ?
                RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text : nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            alertTextField.text = (defaultName == name) ? nil : name
            alertTextField.placeholder = defaultName
            tagNameTextField = alertTextField
        }
        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            if let name = tagNameTextField.text, !name.isEmpty {
                output.viewDidChangeTag(name: name)
            } else {
                output.viewDidChangeTag(name: defaultName)
            }
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Sensor alert custom description dialog

extension TagSettingsViewController {
    private func showSensorCustomAlertDescriptionDialog(
        description: String?,
        sender: TagSettingsAlertConfigCell
    ) {
        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.Alert.CustomDescription.title,
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            alertTextField.text = description
            customAlertDescriptionTextField = alertTextField
        }

        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            let inputText = customAlertDescriptionTextField.text
            notify(sender: sender, inputText: inputText)
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    private func notify(sender: TagSettingsAlertConfigCell, inputText: String?) {
        switch sender {
        case temperatureAlertCell:
            output.viewDidChangeAlertDescription(
                for: .temperature(lower: 0, upper: 0),
                description: inputText
            )
        case humidityAlertCell:
            output.viewDidChangeAlertDescription(
                for: .relativeHumidity(lower: 0, upper: 0),
                description: inputText
            )
        case pressureAlertCell:
            output.viewDidChangeAlertDescription(
                for: .pressure(lower: 0, upper: 0),
                description: inputText
            )
        case rssiAlertCell:
            output.viewDidChangeAlertDescription(
                for: .signal(lower: 0, upper: 0),
                description: inputText
            )
        case movementAlertCell:
            output.viewDidChangeAlertDescription(
                for: .movement(last: 0),
                description: inputText
            )
        case connectionAlertCell:
            output.viewDidChangeAlertDescription(
                for: .connection,
                description: inputText
            )
        case cloudConnectionAlertCell:
            output.viewDidChangeAlertDescription(
                for: .cloudConnection(unseenDuration: 0),
                description: inputText
            )
        default:
            break
        }
    }
}

// MARK: - Sensor alert range settings

extension TagSettingsViewController {
    // swiftlint:disable:next function_parameter_count function_body_length
    private func showSensorCustomAlertRangeDialog(
        title: String?,
        minimumBound: Double,
        maximumBound: Double,
        currentLowerBound: Double?,
        currentUpperBound: Double?,
        sender: TagSettingsAlertConfigCell
    ) {
        let alert = UIAlertController(
            title: title,
            message: nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            let format = RuuviLocalization.TagSettings.AlertSettings.Dialog.min
            alertTextField.placeholder = format(
                Float(minimumBound)
            )
            alertTextField.keyboardType = .decimalPad
            alertMinRangeTextField = alertTextField
            if minimumBound < 0 {
                alertMinRangeTextField.addNumericAccessory()
            }
            if sender == temperatureAlertCell || sender == humidityAlertCell || sender == pressureAlertCell {
                alertTextField.text = measurementService.string(for: currentLowerBound)
            }
        }

        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            let format = RuuviLocalization.TagSettings.AlertSettings.Dialog.max
            alertTextField.placeholder = format(
                Float(maximumBound)
            )
            alertTextField.keyboardType = .decimalPad
            alertMaxRangeTextField = alertTextField
            if maximumBound < 0 {
                alertMaxRangeTextField.addNumericAccessory()
            }
            if sender == temperatureAlertCell || sender == humidityAlertCell || sender == pressureAlertCell {
                alertTextField.text = measurementService.string(for: currentUpperBound)
            }
        }

        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            guard let minimumInputText = alertMinRangeTextField.text,
                  minimumInputText.doubleValue >= minimumBound
            else {
                return
            }

            guard let maximumInputText = alertMaxRangeTextField.text,
                  maximumInputText.doubleValue <= maximumBound
            else {
                return
            }

            didSetAlertRange(
                sender: sender,
                minValue: minimumInputText.doubleValue,
                maxValue: maximumInputText.doubleValue
            )
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

// MARK: - Cloud connection alert delay settings

extension TagSettingsViewController {
    // swiftlint:disable:next function_parameter_count
    private func showSensorCustomAlertRangeDialog(
        title: String?,
        message: String?,
        minimum: Int,
        default _: Int,
        current: Int?,
        sender _: TagSettingsAlertConfigCell
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            alertTextField.keyboardType = .numberPad
            cloudConnectionAlertDelayTextField = alertTextField
            alertTextField.text = current?.stringValue
        }

        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            guard let durationInput = cloudConnectionAlertDelayTextField.text?.intValue,
                  durationInput >= minimum
            else {
                return
            }

            let currentDuration = viewModel?.cloudConnectionAlertUnseenDuration.value?.intValue ?? 900
            if durationInput == (currentDuration / 60) {
                return
            }

            output.viewDidChangeCloudConnectionAlertUnseenDuration(duration: durationInput * 60)
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
}

extension TagSettingsViewController: TagSettingsViewInput {
    func localize() {
        // No op.
    }

    func showTagClaimDialog() {
        let title = RuuviLocalization.claimSensorOwnership
        let message = RuuviLocalization.doYouOwnSensor
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.yes,
            style: .default,
            handler: { [weak self] _ in
                self?.output.viewDidConfirmClaimTag()
            }
        ))
        controller.addAction(UIAlertAction(title: RuuviLocalization.no, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showMacAddressDetail() {
        let title = RuuviLocalization.TagSettings.Mac.Alert.title
        let controller = UIAlertController(title: title, message: viewModel?.mac.value, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: RuuviLocalization.copy, style: .default, handler: { [weak self] _ in
            if let mac = self?.viewModel?.mac.value {
                UIPasteboard.general.string = mac
            }
        }))
        controller.addAction(UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func showFirmwareUpdateDialog() {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog()
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog() {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: nil))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate()
        }))
        present(alert, animated: true)
    }

    func showKeepConnectionTimeoutDialog() {
        let message = RuuviLocalization.TagSettings.PairError.Timeout.description
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(controller, animated: true)
    }

    func resetKeepConnectionSwitch() {
        if let btPairCell {
            btPairCell.configureSwitch(
                value: false,
                hideStatusLabel: viewModel?.hideSwitchStatusLabel.value ?? false
            )
            btPairCell.disableSwitch(disable: false)
        }
    }

    func showKeepConnectionCloudModeDialog() {
        let message = RuuviLocalization.TagSettings.PairError.CloudMode.description
        let controller = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .cancel,
            handler: { [weak self] _ in
                self?.resetKeepConnectionSwitch()
            }
        ))
        present(controller, animated: true)
    }

    func stopKeepConnectionAnimatingDots() {
        if let btPairCell {
            btPairCell.configurePairingAnimation(start: false)
        }
    }

    func startKeepConnectionAnimatingDots() {
        if let btPairCell {
            btPairCell.configurePairingAnimation(start: true)
        }
    }

    func showCSVExportLocationDialog() {
        let title = RuuviLocalization.exportHistory
        let message = RuuviLocalization.exportCsvFeatureLocation
        let controller = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        controller.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .cancel,
            handler: nil
        ))
        present(controller, animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension TagSettingsViewController: UITextFieldDelegate {
    // swiftlint:disable:next cyclomatic_complexity
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,

        replacementString string: String
    ) -> Bool {
        guard let text = textField.text
        else {
            return true
        }
        let limit = text.utf16.count + string.utf16.count - range.length
        if textField == tagNameTextField {
            if limit <= tagNameCharaterLimit {
                return true
            } else {
                return false
            }
        } else if textField == customAlertDescriptionTextField {
            if limit <= customAlertDescriptionCharacterLimit {
                return true
            } else {
                return false
            }
        } else if textField == alertMinRangeTextField || textField == alertMaxRangeTextField {
            guard let text = textField.text, let decimalSeparator = NSLocale.current.decimalSeparator
            else {
                return true
            }

            var splitText = text.components(separatedBy: decimalSeparator)
            let totalDecimalSeparators = splitText.count - 1
            let isEditingEnd = (text.count - 3) < range.lowerBound

            splitText.removeFirst()

            // Check if we will exceed 2 dp
            if
                splitText.last?.count ?? 0 > 1, string.count != 0,
                isEditingEnd {
                return false
            }

            // If there is already a dot we don't want to allow further dots
            if totalDecimalSeparators > 0, string == decimalSeparator {
                return false
            }

            // Only allow numbers and decimal separator
            switch string {
            case "", "-", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", decimalSeparator:
                return true
            default:
                return false
            }
        } else if textField == cloudConnectionAlertDelayTextField {
            if limit <= cloudConnectionAlertDelayCharaterLimit {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}
