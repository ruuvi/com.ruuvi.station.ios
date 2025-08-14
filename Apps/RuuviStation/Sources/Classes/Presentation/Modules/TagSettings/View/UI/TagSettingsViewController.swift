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
    case alertAQI
    case alertCarbonDioxide
    case alertPMatter1
    case alertPMatter25
    case alertPMatter4
    case alertPMatter10
    case alertVOC
    case alertNOx
    case alertSoundInstant
    case alertLuminosity
    case offsetCorrection
    case moreInfo
    case firmware
    case remove
}

enum TagSettingsItemCellIdentifier: Int {
    case generalChangeBackground = 0
    case generalName = 1
    case generalOwner = 2
    case generalOwnersPlan = 3
    case generalShare = 4
    case offsetTemperature = 5
    case offsetHumidity = 6
    case offsetPressure = 7
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

    var maxShareCount: Int = 10

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
    private let commonHeaderHeight: CGFloat = 48

    private var frozenContentOffsetForRowAnimation: CGPoint?

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
    private lazy var changeBackgroundCell: TagSettingsBasicCell? = TagSettingsBasicCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

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
                temperatureAlertItem()
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

    // AQI
    private lazy var aqiAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var aqiAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Carbon Dioxide
    private lazy var co2AlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var co2AlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // PM1
    private lazy var pm1AlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var pm1AlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // PM2.5
    private lazy var pm25AlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var pm25AlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // PM4
    private lazy var pm4AlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var pm4AlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // PM10
    private lazy var pm10AlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var pm10AlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // VOC
    private lazy var vocAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var vocAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // NOX
    private lazy var noxAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var noxAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Sound Instant
    private lazy var soundInstantAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var soundInstantAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
        style: .value1,
        reuseIdentifier: Self.ReuseIdentifier
    )

    // Luminosity
    private lazy var luminosityAlertSectionHeaderView:
        TagSettingsExpandableSectionHeader? = TagSettingsExpandableSectionHeader()

    private lazy var luminosityAlertCell: TagSettingsAlertConfigCell? = TagSettingsAlertConfigCell(
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
        changeBackgroundCell = nil
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
        aqiAlertSectionHeaderView = nil
        aqiAlertCell = nil
        co2AlertSectionHeaderView = nil
        co2AlertCell = nil
        pm1AlertSectionHeaderView = nil
        pm1AlertCell = nil
        pm25AlertSectionHeaderView = nil
        pm25AlertCell = nil
        pm4AlertSectionHeaderView = nil
        pm4AlertCell = nil
        pm10AlertSectionHeaderView = nil
        pm10AlertCell = nil
        vocAlertSectionHeaderView = nil
        vocAlertCell = nil
        noxAlertSectionHeaderView = nil
        noxAlertCell = nil
        soundInstantAlertSectionHeaderView = nil
        soundInstantAlertCell = nil
        luminosityAlertSectionHeaderView = nil
        luminosityAlertCell = nil
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
        tableView.performBatchUpdates({
            tableView.reloadData()
        }, completion: { [weak self] completed in
            if completed {
                self?.frozenContentOffsetForRowAnimation = self?.tableView.contentOffset
            }
        })
    }

    private func reloadSection(index: Int) {
        let originalContentOffset = tableView.contentOffset
        tableView.beginUpdates()

        let section = NSIndexSet(index: index) as IndexSet
        tableView.reloadSections(section, with: .fade)

        tableView.endUpdates()

        if tableView.contentOffset != originalContentOffset {
            frozenContentOffsetForRowAnimation = tableView.contentOffset
        }
    }

    private func reloadSection(identifier: TagSettingsSectionIdentifier) {
        switch identifier {
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
        case .btPair:
            if let currentSection = tableViewSections.first(where: {
                $0.identifier == section
            }) {
                let btPairItem = tagPairSettingItem()
                let sectionIndex = indexOfSection(section: section)
                let indexPath = IndexPath(row: 0, section: sectionIndex)

                UIView.setAnimationsEnabled(false)
                tableView.performBatchUpdates({
                    if currentSection.cells.count > 0 {
                        currentSection.cells.remove(at: 0)
                        currentSection.cells.insert(btPairItem, at: 0)
                        tableView.deleteRows(at: [indexPath], with: .none)
                        tableView.insertRows(at: [indexPath], with: .none)
                    }
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

// MARK: ScrollViewDelegate

extension TagSettingsViewController: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        frozenContentOffsetForRowAnimation = nil
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let overrideOffset = frozenContentOffsetForRowAnimation,
            scrollView.contentOffset != overrideOffset {
            scrollView.setContentOffset(overrideOffset, animated: false)
        }
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
            changeBackgroundItem(),
            tagNameSettingItem(),
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
            title: "",
            cells: availableItems,
            collapsed: false,
            headerType: .simple
        )
        return section
    }

    private func changeBackgroundItem() -> TagSettingsItem {
        let settingItem = TagSettingsItem(
            identifier: .generalChangeBackground,
            createdCell: { [weak self] in
                self?.changeBackgroundCell?.configure(
                    title: RuuviLocalization.TagSettings.BackgroundImageLabel.text,
                    value: nil
                )
                self?.changeBackgroundCell?.setAccessory(type: .background)
                return self?.changeBackgroundCell ?? UITableViewCell()
            },
            action: { [weak self] _ in
                self?.didTapChangeBackground()
            }
        )
        return settingItem
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
                self?.reloadCellsFor(section: .btPair)
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
                self?.reloadCellsFor(section: .btPair)
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

            temperatureAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertTemperature
                )
                guard let sSelf = self else {
                    return
                }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .temperature(
                            lower: 0,
                            upper: 0
                        )
                    )
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
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .relativeHumidity(
                            lower: 0,
                            upper: 0
                        )
                    )
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
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .pressure(
                            lower: 0,
                            upper: 0
                        )
                    )
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

            rssiAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                let isClaimed = GlobalHelpers.getBool(from: viewModel.isClaimedTag.value)
                cell.disableEditing(
                    disable: measurement == nil || !isClaimed,
                    identifier: .alertRSSI
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .signal(
                            lower: 0,
                            upper: 0
                        )
                    )
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

        // AQI
        if let aqiAlertCell {
            aqiAlertCell.bind(viewModel.isAQIAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            aqiAlertCell.bind(viewModel.aqiAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            aqiAlertCell.bind(viewModel.aqiUpperBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(
                        description: self?.aqiAlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.aqiLowerBound(),
                    selectedMaxValue: self?.aqiUpperBound()
                )
            }

            aqiAlertCell.bind(viewModel.aqiLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.aqiAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.aqiLowerBound(),
                    selectedMaxValue: self?.aqiUpperBound()
                )
            }

            aqiAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertAQI
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .aqi(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let aqiAlertSectionHeaderView {
            aqiAlertSectionHeaderView.bind(
                viewModel.aqiAlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isAQIAlertOn.value)
                    let alertState = viewModel.aqiAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            aqiAlertSectionHeaderView
                .bind(viewModel.isAQIAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.aqiAlertState.value
                    let mutedTill = viewModel.aqiAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            aqiAlertSectionHeaderView
                .bind(viewModel.aqiAlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isAQIAlertOn.value)
                    let mutedTill = viewModel.aqiAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Carbon Dioxide
        if let co2AlertCell {
            co2AlertCell.bind(viewModel.isCarbonDioxideAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            co2AlertCell.bind(viewModel.carbonDioxideAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            co2AlertCell.bind(viewModel.carbonDioxideUpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.co2AlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.co2LowerBound(),
                    selectedMaxValue: self?.co2UpperBound()
                )
            }

            co2AlertCell.bind(viewModel.carbonDioxideLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.co2AlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.co2LowerBound(),
                    selectedMaxValue: self?.co2UpperBound()
                )
            }

            co2AlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertCarbonDioxide
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .carbonDioxide(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let co2AlertSectionHeaderView {
            co2AlertSectionHeaderView.bind(
                viewModel.carbonDioxideAlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isCarbonDioxideAlertOn.value)
                    let alertState = viewModel.carbonDioxideAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            co2AlertSectionHeaderView
                .bind(viewModel.isCarbonDioxideAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.carbonDioxideAlertState.value
                    let mutedTill = viewModel.carbonDioxideAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            co2AlertSectionHeaderView
                .bind(viewModel.carbonDioxideAlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isCarbonDioxideAlertOn.value)
                    let mutedTill = viewModel.carbonDioxideAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // PM1
        if let pm1AlertCell {
            pm1AlertCell.bind(viewModel.isPMatter1AlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            pm1AlertCell.bind(viewModel.pMatter1AlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            pm1AlertCell.bind(viewModel.pMatter1UpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.pm1AlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.pm1LowerBound(),
                    selectedMaxValue: self?.pm1UpperBound()
                )
            }

            pm1AlertCell.bind(viewModel.pMatter1LowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.pm1AlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.pm1LowerBound(),
                    selectedMaxValue: self?.pm1UpperBound()
                )
            }

            pm1AlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertPMatter1
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .pMatter1(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let pm1AlertSectionHeaderView {
            pm1AlertSectionHeaderView.bind(
                viewModel.pMatter1AlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter1AlertOn.value)
                    let alertState = viewModel.pMatter1AlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm1AlertSectionHeaderView
                .bind(viewModel.isPMatter1AlertOn) {
                    [weak self] header,
                    isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.pMatter1AlertState.value
                    let mutedTill = viewModel.pMatter1AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm1AlertSectionHeaderView
                .bind(viewModel.pMatter1AlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter1AlertOn.value)
                    let mutedTill = viewModel.pMatter1AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // PM2.5
        if let pm25AlertCell {
            pm25AlertCell.bind(viewModel.isPMatter25AlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            pm25AlertCell.bind(viewModel.pMatter25AlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            pm25AlertCell.bind(viewModel.pMatter25UpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.pm25AlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.pm25LowerBound(),
                    selectedMaxValue: self?.pm25UpperBound()
                )
            }

            pm25AlertCell.bind(viewModel.pMatter25LowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.pm25AlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.pm25LowerBound(),
                    selectedMaxValue: self?.pm25UpperBound()
                )
            }

            pm25AlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertPMatter25
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .pMatter25(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let pm25AlertSectionHeaderView {
            pm25AlertSectionHeaderView.bind(
                viewModel.pMatter25AlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter25AlertOn.value)
                    let alertState = viewModel.pMatter25AlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm25AlertSectionHeaderView
                .bind(viewModel.isPMatter25AlertOn) {
                    [weak self] header,
                    isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.pMatter25AlertState.value
                    let mutedTill = viewModel.pMatter25AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm25AlertSectionHeaderView
                .bind(viewModel.pMatter25AlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter25AlertOn.value)
                    let mutedTill = viewModel.pMatter25AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // PM4
        if let pm4AlertCell {
            pm4AlertCell.bind(viewModel.isPMatter4AlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            pm4AlertCell.bind(viewModel.pMatter4AlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            pm4AlertCell.bind(viewModel.pMatter4UpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.pm4AlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.pm4LowerBound(),
                    selectedMaxValue: self?.pm4UpperBound()
                )
            }

            pm4AlertCell.bind(viewModel.pMatter4LowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.pm4AlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.pm4LowerBound(),
                    selectedMaxValue: self?.pm4UpperBound()
                )
            }

            pm4AlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertPMatter4
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .pMatter4(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let pm4AlertSectionHeaderView {
            pm4AlertSectionHeaderView.bind(
                viewModel.pMatter4AlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter4AlertOn.value)
                    let alertState = viewModel.pMatter4AlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm4AlertSectionHeaderView
                .bind(viewModel.isPMatter4AlertOn) {
                    [weak self] header,
                    isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.pMatter4AlertState.value
                    let mutedTill = viewModel.pMatter4AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm4AlertSectionHeaderView
                .bind(viewModel.pMatter4AlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter4AlertOn.value)
                    let mutedTill = viewModel.pMatter4AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // PM10
        if let pm10AlertCell {
            pm10AlertCell.bind(viewModel.isPMatter10AlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            pm10AlertCell.bind(viewModel.pMatter10AlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            pm10AlertCell.bind(viewModel.pMatter10UpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.pm10AlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.pm10LowerBound(),
                    selectedMaxValue: self?.pm10UpperBound()
                )
            }

            pm10AlertCell.bind(viewModel.pMatter10LowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.pm10AlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.pm10LowerBound(),
                    selectedMaxValue: self?.pm10UpperBound()
                )
            }

            pm10AlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertPMatter10
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .pMatter10(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let pm10AlertSectionHeaderView {
            pm10AlertSectionHeaderView.bind(
                viewModel.pMatter10AlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter10AlertOn.value)
                    let alertState = viewModel.pMatter10AlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm10AlertSectionHeaderView
                .bind(viewModel.isPMatter10AlertOn) {
                    [weak self] header,
                    isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.pMatter10AlertState.value
                    let mutedTill = viewModel.pMatter10AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            pm10AlertSectionHeaderView
                .bind(viewModel.pMatter10AlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isPMatter10AlertOn.value)
                    let mutedTill = viewModel.pMatter10AlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // VOC
        if let vocAlertCell {
            vocAlertCell.bind(viewModel.isVOCAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            vocAlertCell.bind(viewModel.vocAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            vocAlertCell.bind(viewModel.vocUpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.vocAlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.vocLowerBound(),
                    selectedMaxValue: self?.vocUpperBound()
                )
            }

            vocAlertCell.bind(viewModel.vocLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.vocAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.vocLowerBound(),
                    selectedMaxValue: self?.vocUpperBound()
                )
            }

            vocAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertVOC
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .voc(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let vocAlertSectionHeaderView {
            vocAlertSectionHeaderView.bind(
                viewModel.vocAlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isVOCAlertOn.value)
                    let alertState = viewModel.vocAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            vocAlertSectionHeaderView
                .bind(viewModel.isVOCAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.vocAlertState.value
                    let mutedTill = viewModel.vocAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            vocAlertSectionHeaderView
                .bind(viewModel.vocAlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isVOCAlertOn.value)
                    let mutedTill = viewModel.vocAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // NOX
        if let noxAlertCell {
            noxAlertCell.bind(viewModel.isNOXAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            noxAlertCell.bind(viewModel.noxAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            noxAlertCell.bind(viewModel.noxUpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.noxAlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.noxLowerBound(),
                    selectedMaxValue: self?.noxUpperBound()
                )
            }

            noxAlertCell.bind(viewModel.noxLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.noxAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.noxLowerBound(),
                    selectedMaxValue: self?.noxUpperBound()
                )
            }

            noxAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertNOx
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .nox(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let noxAlertSectionHeaderView {
            noxAlertSectionHeaderView.bind(
                viewModel.carbonDioxideAlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isNOXAlertOn.value)
                    let alertState = viewModel.noxAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            noxAlertSectionHeaderView
                .bind(viewModel.isNOXAlertOn) { [weak self] header, isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.noxAlertState.value
                    let mutedTill = viewModel.noxAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            noxAlertSectionHeaderView
                .bind(viewModel.noxAlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isNOXAlertOn.value)
                    let mutedTill = viewModel.noxAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Sound Instant
        if let soundInstantAlertCell {
            soundInstantAlertCell.bind(viewModel.isSoundInstantAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            soundInstantAlertCell.bind(viewModel.soundInstantAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            soundInstantAlertCell.bind(viewModel.soundInstantUpperBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.soundAlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.soundLowerBound(),
                    selectedMaxValue: self?.soundUpperBound()
                )
            }

            soundInstantAlertCell.bind(viewModel.soundInstantLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.soundAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.soundLowerBound(),
                    selectedMaxValue: self?.soundUpperBound()
                )
            }

            soundInstantAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertSoundInstant
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .soundInstant(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let soundInstantAlertSectionHeaderView {
            soundInstantAlertSectionHeaderView.bind(viewModel.soundInstantAlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isSoundInstantAlertOn.value)
                    let alertState = viewModel.soundInstantAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            soundInstantAlertSectionHeaderView
                .bind(viewModel.isSoundInstantAlertOn) {
                    [weak self] header,
                    isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.soundInstantAlertState.value
                    let mutedTill = viewModel.soundInstantAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            soundInstantAlertSectionHeaderView
                .bind(viewModel.soundInstantAlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isSoundInstantAlertOn.value)
                    let mutedTill = viewModel.soundInstantAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: state)
                }
        }

        // Luminosity
        if let luminosityAlertCell {
            luminosityAlertCell
                .bind(viewModel.isLuminosityAlertOn) { cell, value in
                cell.setStatus(
                    with: value,
                    hideStatusLabel: viewModel.hideSwitchStatusLabel.value ?? false
                )
            }

            luminosityAlertCell.bind(viewModel.luminosityAlertDescription) {
                [weak self] cell, value in
                cell.setCustomDescription(with: self?.alertCustomDescription(from: value))
            }

            luminosityAlertCell.bind(viewModel.luminosityLowerBound) {
                [weak self] cell, _ in
                cell
                    .setAlertLimitDescription(
                        description: self?.luminosityAlertRangeDescription()
                    )
                cell.setAlertRange(
                    selectedMinValue: self?.luminosityLowerBound(),
                    selectedMaxValue: self?.luminosityUpperBound()
                )
            }

            luminosityAlertCell.bind(viewModel.luminosityLowerBound) {
                [weak self] cell, _ in
                cell.setAlertLimitDescription(description: self?.luminosityAlertRangeDescription())
                cell.setAlertRange(
                    selectedMinValue: self?.luminosityLowerBound(),
                    selectedMaxValue: self?.luminosityUpperBound()
                )
            }

            luminosityAlertCell.bind(viewModel.latestMeasurement) { [weak self]
                cell, measurement in
                cell.disableEditing(
                    disable: measurement == nil,
                    identifier: .alertLuminosity
                )
                guard let sSelf = self else { return }
                cell.setLatestMeasurementText(
                    with: sSelf.latestValue(
                        for: .luminosity(
                            lower: 0,
                            upper: 0
                        )
                    )
                )
            }
        }

        if let luminosityAlertSectionHeaderView {
            luminosityAlertSectionHeaderView.bind(
                viewModel.luminosityAlertMutedTill) {
                    [weak self] header,
                    mutedTill in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isLuminosityAlertOn.value)
                    let alertState = viewModel.luminosityAlertState.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            luminosityAlertSectionHeaderView
                .bind(viewModel.isLuminosityAlertOn) {
                    [weak self] header,
                    isOn in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                        GlobalHelpers.getBool(from: isOn)
                    let alertState = viewModel.luminosityAlertState.value
                    let mutedTill = viewModel.luminosityAlertMutedTill.value
                    header.setAlertState(with: mutedTill, isOn: isOn, alertState: alertState)
                }

            luminosityAlertSectionHeaderView
                .bind(viewModel.luminosityAlertState) {
                    [weak self] header,
                    state in
                    guard let self else { return }
                    let isOn = alertsAvailable() &&
                    GlobalHelpers
                        .getBool(from: viewModel.isLuminosityAlertOn.value)
                    let mutedTill = viewModel.luminosityAlertMutedTill.value
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

    // swiftlint:disable:next cyclomatic_complexity
    private func configureAlertSections() -> [TagSettingsSection] {
        var sections: [TagSettingsSection] = []

        // Fixed items
        sections += [
            configureAlertHeaderSection(),
        ]

        // Variable items
        if viewModel?.latestMeasurement.value?.co2 != nil &&
            viewModel?.latestMeasurement.value?.pm25 != nil {
            sections.append(configureAQIAlertSection())
        }

        if viewModel?.latestMeasurement.value?.co2 != nil {
            sections.append(configureCO2AlertSection())
        }

        if viewModel?.latestMeasurement.value?.pm25 != nil {
            sections.append(configurePM25AlertSection())
        }

        if viewModel?.latestMeasurement.value?.voc != nil {
            sections.append(configureVOCAlertSection())
        }

        if viewModel?.latestMeasurement.value?.nox != nil {
            sections.append(configureNOXAlertSection())
        }

        if viewModel?.latestMeasurement.value?.temperature != nil {
            sections.append(configureTemperatureAlertSection())
        }

        if viewModel?.latestMeasurement.value?.humidity != nil {
            sections.append(configureHumidityAlertSection())
        }

        if viewModel?.latestMeasurement.value?.pressure != nil {
            sections.append(configurePressureAlertSection())
        }

        if viewModel?.latestMeasurement.value?.luminance != nil {
            sections.append(configureLuminosityAlertSection())
        }

        if viewModel?.latestMeasurement.value?.movementCounter != nil {
            sections.append(configureMovementAlertSection())
        }

        if viewModel?.latestMeasurement.value?.dbaInstant != nil {
            sections.append(configureSoundAlertSection())
        }

        if viewModel?.latestMeasurement.value?.rssi != nil {
            sections.append(configureRSSIAlertSection())
        }

        if viewModel?.isConnectable != nil {
            sections.append(configureConnectionAlertSection())
        }

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

    private func temperatureAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = temperatureMinMaxForSliders()
        let disableTemperature = !hasMeasurement()
        let latestMeasurement = latestValue(for: .temperature(lower: 0, upper: 0))
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
                self?.temperatureAlertCell?.setLatestMeasurementText(with: latestMeasurement)
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
        let latestMeasurement = latestValue(for: .relativeHumidity(lower: 0, upper: 0))
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
                self?.humidityAlertCell?.setLatestMeasurementText(with: latestMeasurement)
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
        let latestMeasurement = latestValue(for: .pressure(lower: 0, upper: 0))
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
                self?.pressureAlertCell?.setLatestMeasurementText(with: latestMeasurement)
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
        let latestMeasurement = latestValue(for: .signal(lower: 0, upper: 0))
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
                self?.rssiAlertCell?.setLatestMeasurementText(with: latestMeasurement)
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

    // MARK: - AQI ALERTS

    private func configureAQIAlertSection() -> TagSettingsSection {
        let sectionTitle = RuuviLocalization.aqi
        let section = TagSettingsSection(
            identifier: .alertAQI,
            title: sectionTitle,
            cells: [
                aqiAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func aqiAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = aqiAlertRange()
        let disableAQI = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .aqi(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.aqiAlertCell?.hideNoticeView()
                self?.aqiAlertCell?.showAlertRangeSetter()
                self?.aqiAlertCell?
                    .setStatus(
                        with: self?.viewModel?.isAQIAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.aqiAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .aqiAlertDescription.value))
                self?.aqiAlertCell?
                    .setAlertLimitDescription(
                        description: self?.aqiAlertRangeDescription()
                    )
                self?.aqiAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.aqiLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.aqiUpperBound()
                )
                self?.aqiAlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.aqiAlertCell?.disableEditing(
                    disable: disableAQI,
                    identifier: .alertAQI
                )
                self?.aqiAlertCell?.delegate = self
                return self?.aqiAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - CO2 ALERTS

    private func configureCO2AlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.Co2AlertTitleLabel.text(
            RuuviLocalization.unitCo2
        )
        let section = TagSettingsSection(
            identifier: .alertCarbonDioxide,
            title: title,
            cells: [
                co2AlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func co2AlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = co2AlertRange()
        let disableCo2 = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .carbonDioxide(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.co2AlertCell?.hideNoticeView()
                self?.co2AlertCell?.showAlertRangeSetter()
                self?.co2AlertCell?
                    .setStatus(
                        with: self?.viewModel?.isCarbonDioxideAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.co2AlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .carbonDioxideAlertDescription.value))
                self?.co2AlertCell?
                    .setAlertLimitDescription(
                        description: self?.co2AlertRangeDescription()
                    )
                self?.co2AlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.co2LowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.co2UpperBound()
                )
                self?.co2AlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.co2AlertCell?.disableEditing(
                    disable: disableCo2,
                    identifier: .alertCarbonDioxide
                )
                self?.co2AlertCell?.delegate = self
                return self?.co2AlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - PM1 ALERTS

    private func configurePM1AlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.Pm10AlertTitleLabel.text(
            RuuviLocalization.unitPm10
        )
        let section = TagSettingsSection(
            identifier: .alertPMatter1,
            title: title,
            cells: [
                pm1AlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func pm1AlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = pmAlertRange()
        let disablePM1 = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .pMatter1(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.pm1AlertCell?.hideNoticeView()
                self?.pm1AlertCell?.showAlertRangeSetter()
                self?.pm1AlertCell?
                    .setStatus(
                        with: self?.viewModel?.isPMatter1AlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.pm1AlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .pMatter1AlertDescription.value))
                self?.pm1AlertCell?
                    .setAlertLimitDescription(
                        description: self?.pm1AlertRangeDescription()
                    )
                self?.pm1AlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.pm1LowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.pm1UpperBound()
                )
                self?.pm1AlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.pm1AlertCell?.disableEditing(
                    disable: disablePM1,
                    identifier: .alertPMatter1
                )
                self?.pm1AlertCell?.delegate = self
                return self?.pm1AlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - PM2.5 ALERTS

    private func configurePM25AlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.Pm25AlertTitleLabel.text(
            RuuviLocalization.unitPm25
        )
        let section = TagSettingsSection(
            identifier: .alertPMatter25,
            title: title,
            cells: [
                pm25AlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func pm25AlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = pmAlertRange()
        let disablePM = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .pMatter25(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.pm25AlertCell?.hideNoticeView()
                self?.pm25AlertCell?.showAlertRangeSetter()
                self?.pm25AlertCell?
                    .setStatus(
                        with: self?.viewModel?.isPMatter25AlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.pm25AlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .pMatter25AlertDescription.value))
                self?.pm25AlertCell?
                    .setAlertLimitDescription(
                        description: self?.pm25AlertRangeDescription()
                    )
                self?.pm25AlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.pm25LowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.pm25UpperBound()
                )
                self?.pm25AlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.pm25AlertCell?.disableEditing(
                    disable: disablePM,
                    identifier: .alertPMatter25
                )
                self?.pm25AlertCell?.delegate = self
                return self?.pm25AlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - PM4 ALERTS

    private func configurePM4AlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.Pm40AlertTitleLabel.text(
            RuuviLocalization.unitPm40
        )
        let section = TagSettingsSection(
            identifier: .alertPMatter4,
            title: title,
            cells: [
                pm4AlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func pm4AlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = pmAlertRange()
        let disablePM = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .pMatter4(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.pm4AlertCell?.hideNoticeView()
                self?.pm4AlertCell?.showAlertRangeSetter()
                self?.pm4AlertCell?
                    .setStatus(
                        with: self?.viewModel?.isPMatter4AlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.pm4AlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .pMatter4AlertDescription.value))
                self?.pm4AlertCell?
                    .setAlertLimitDescription(
                        description: self?.pm4AlertRangeDescription()
                    )
                self?.pm4AlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.pm4LowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.pm4UpperBound()
                )
                self?.pm4AlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.pm4AlertCell?.disableEditing(
                    disable: disablePM,
                    identifier: .alertPMatter4
                )
                self?.pm4AlertCell?.delegate = self
                return self?.pm4AlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - PM10 ALERTS

    private func configurePM10AlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.Pm100AlertTitleLabel.text(
            RuuviLocalization.unitPm100
        )
        let section = TagSettingsSection(
            identifier: .alertPMatter10,
            title: title,
            cells: [
                pm10AlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func pm10AlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = pmAlertRange()
        let disablePM = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .pMatter10(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.pm10AlertCell?.hideNoticeView()
                self?.pm10AlertCell?.showAlertRangeSetter()
                self?.pm10AlertCell?
                    .setStatus(
                        with: self?.viewModel?.isPMatter10AlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.pm10AlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .pMatter10AlertDescription.value))
                self?.pm10AlertCell?
                    .setAlertLimitDescription(
                        description: self?.pm10AlertRangeDescription()
                    )
                self?.pm10AlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.pm10LowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.pm10UpperBound()
                )
                self?.pm10AlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.pm10AlertCell?.disableEditing(
                    disable: disablePM,
                    identifier: .alertPMatter10
                )
                self?.pm10AlertCell?.delegate = self
                return self?.pm10AlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - VOC ALERTS

    private func configureVOCAlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.VocAlertTitleLabel.text(
            RuuviLocalization.unitVoc
        )
        let section = TagSettingsSection(
            identifier: .alertVOC,
            title: title,
            cells: [
                vocAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func vocAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = vocAlertRange()
        let disableVOC = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .voc(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.vocAlertCell?.hideNoticeView()
                self?.vocAlertCell?.showAlertRangeSetter()
                self?.vocAlertCell?
                    .setStatus(
                        with: self?.viewModel?.isVOCAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.vocAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .vocAlertDescription.value))
                self?.vocAlertCell?
                    .setAlertLimitDescription(
                        description: self?.vocAlertRangeDescription()
                    )
                self?.vocAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.vocLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.vocUpperBound()
                )
                self?.vocAlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.vocAlertCell?.disableEditing(
                    disable: disableVOC,
                    identifier: .alertVOC
                )
                self?.vocAlertCell?.delegate = self
                return self?.vocAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - NOx ALERTS

    private func configureNOXAlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.NoxAlertTitleLabel.text(
            RuuviLocalization.unitNox
        )
        let section = TagSettingsSection(
            identifier: .alertNOx,
            title: title,
            cells: [
                noxAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func noxAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = noxAlertRange()
        let disableNOX = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .nox(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.noxAlertCell?.hideNoticeView()
                self?.noxAlertCell?.showAlertRangeSetter()
                self?.noxAlertCell?
                    .setStatus(
                        with: self?.viewModel?.isNOXAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.noxAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .noxAlertDescription.value))
                self?.noxAlertCell?
                    .setAlertLimitDescription(
                        description: self?.noxAlertRangeDescription()
                    )
                self?.noxAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.noxLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.noxUpperBound()
                )
                self?.noxAlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.noxAlertCell?.disableEditing(
                    disable: disableNOX,
                    identifier: .alertNOx
                )
                self?.noxAlertCell?.delegate = self
                return self?.noxAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - SOUND ALERTS

    private func configureSoundAlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.SoundInstantAlertTitleLabel.text(
            RuuviLocalization.unitSound
        )
        let section = TagSettingsSection(
            identifier: .alertSoundInstant,
            title: title,
            cells: [
                soundAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func soundAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = soundAlertRange()
        let disableSound = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .soundInstant(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.soundInstantAlertCell?.hideNoticeView()
                self?.soundInstantAlertCell?.showAlertRangeSetter()
                self?.soundInstantAlertCell?
                    .setStatus(
                        with: self?.viewModel?.isSoundInstantAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.soundInstantAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .soundInstantAlertDescription.value))
                self?.soundInstantAlertCell?
                    .setAlertLimitDescription(
                        description: self?.soundAlertRangeDescription()
                    )
                self?.soundInstantAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.soundLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.soundUpperBound()
                )
                self?.soundInstantAlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.soundInstantAlertCell?.disableEditing(
                    disable: disableSound,
                    identifier: .alertSoundInstant
                )
                self?.soundInstantAlertCell?.delegate = self
                return self?.soundInstantAlertCell ?? UITableViewCell()
            },
            action: nil
        )
        return settingItem
    }

    // MARK: - LUMINOSITY ALERTS

    private func configureLuminosityAlertSection() -> TagSettingsSection {
        let title = RuuviLocalization.TagSettings.LuminosityAlertTitleLabel.text(
            RuuviLocalization.unitLuminosity
        )
        let section = TagSettingsSection(
            identifier: .alertLuminosity,
            title: title,
            cells: [
                luminosityAlertItem()
            ],
            collapsed: true,
            headerType: .expandable
        )
        return section
    }

    private func luminosityAlertItem() -> TagSettingsItem {
        let (minRange, maxRange) = co2AlertRange()
        let disableLuminosity = !hasMeasurement()
        let latestMeasurement = latestValue(
            for: .luminosity(lower: 0, upper: 0)
        )
        let settingItem = TagSettingsItem(
            createdCell: {
                [weak self] in
                self?.luminosityAlertCell?.hideNoticeView()
                self?.luminosityAlertCell?.showAlertRangeSetter()
                self?.luminosityAlertCell?
                    .setStatus(
                        with: self?.viewModel?.isLuminosityAlertOn.value,
                        hideStatusLabel: self?.viewModel?.hideSwitchStatusLabel.value ?? false
                    )
                self?.luminosityAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .luminosityAlertDescription.value))
                self?.luminosityAlertCell?
                    .setAlertLimitDescription(
                        description: self?.luminosityAlertRangeDescription()
                    )
                self?.luminosityAlertCell?.setAlertRange(
                    minValue: minRange,
                    selectedMinValue: self?.luminosityLowerBound(),
                    maxValue: maxRange,
                    selectedMaxValue: self?.luminosityUpperBound()
                )
                self?.luminosityAlertCell?.setLatestMeasurementText(with: latestMeasurement)
                self?.luminosityAlertCell?.disableEditing(
                    disable: disableLuminosity,
                    identifier: .alertLuminosity
                )
                self?.luminosityAlertCell?.delegate = self
                return self?.luminosityAlertCell ?? UITableViewCell()
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
                self?.movementAlertCell?.hideLatestMeasurement()
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
                self?.connectionAlertCell?.hideLatestMeasurement()
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
        let duration = viewModel?.cloudConnectionAlertUnseenDuration.value?.intValue ??
                TagSettingsAlertConstants.CloudConnection.defaultUnseenDuration
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.cloudConnectionAlertCell?.hideAlertRangeSlider()
                self?.cloudConnectionAlertCell?.showAlertLimitDescription()
                self?.cloudConnectionAlertCell?.hideNoticeView()
                self?.cloudConnectionAlertCell?.hideLatestMeasurement()
                self?.cloudConnectionAlertCell?.hideAdditionalTextview()
                self?.cloudConnectionAlertCell?
                    .setCustomDescription(
                        with: self?.alertCustomDescription(from: self?.viewModel?
                            .cloudConnectionAlertDescription.value))
                self?.cloudConnectionAlertCell?
                    .setAlertLimitDescription(
                        description: self?.cloudConnectionAlertRangeDescription(
                            from: duration / 60 // Convert to minutes
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
            viewModel?.isConnected.value ?? false ||
            viewModel?.serviceUUID.value != nil)
    }

    private func reloadAlertSectionHeaders() {
        reloadTemperatureAlertSectionHeader()
        reloadRHAlertSectionHeader()
        reloadPressureAlertSectionHeader()
        reloadSignalAlertSectionHeader()
        reloadAQIAlertSectionHeader()
        reloadCo2AlertSectionHeader()
        reloadPM1AlertSectionHeader()
        reloadPM25AlertSectionHeader()
        reloadPM4AlertSectionHeader()
        reloadPM10AlertSectionHeader()
        reloadVOCAlertSectionHeader()
        reloadNOXAlertSectionHeader()
        reloadSoundInstantAlertSectionHeader()
        reloadLuminosityAlertSectionHeader()
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

    private func reloadAQIAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isAQIAlertOn.value
        )
        let mutedTill = viewModel?.aqiAlertMutedTill.value
        let alertState = viewModel?.aqiAlertState.value
        aqiAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadCo2AlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isCarbonDioxideAlertOn.value
        )
        let mutedTill = viewModel?.carbonDioxideAlertMutedTill.value
        let alertState = viewModel?.carbonDioxideAlertState.value
        co2AlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadPM1AlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isPMatter1AlertOn.value
        )
        let mutedTill = viewModel?.pMatter1AlertMutedTill.value
        let alertState = viewModel?.pMatter1AlertState.value
        pm1AlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadPM25AlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isPMatter25AlertOn.value
        )
        let mutedTill = viewModel?.pMatter25AlertMutedTill.value
        let alertState = viewModel?.pMatter25AlertState.value
        pm25AlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadPM4AlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isPMatter4AlertOn.value
        )
        let mutedTill = viewModel?.pMatter4AlertMutedTill.value
        let alertState = viewModel?.pMatter4AlertState.value
        pm4AlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadPM10AlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isPMatter10AlertOn.value
        )
        let mutedTill = viewModel?.pMatter10AlertMutedTill.value
        let alertState = viewModel?.pMatter10AlertState.value
        pm10AlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadVOCAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isVOCAlertOn.value
        )
        let mutedTill = viewModel?.vocAlertMutedTill.value
        let alertState = viewModel?.vocAlertState.value
        vocAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadNOXAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isNOXAlertOn.value
        )
        let mutedTill = viewModel?.noxAlertMutedTill.value
        let alertState = viewModel?.noxAlertState.value
        noxAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadSoundInstantAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isSoundInstantAlertOn.value
        )
        let mutedTill = viewModel?.soundInstantAlertMutedTill.value
        let alertState = viewModel?.soundInstantAlertState.value
        soundInstantAlertSectionHeaderView?
            .setAlertState(
                with: mutedTill,
                isOn: isOn,
                alertState: alertState
            )
    }

    private func reloadLuminosityAlertSectionHeader() {
        let isOn = alertsAvailable() && GlobalHelpers.getBool(
            from: viewModel?.isLuminosityAlertOn.value
        )
        let mutedTill = viewModel?.luminosityAlertMutedTill.value
        let alertState = viewModel?.luminosityAlertState.value
        luminosityAlertSectionHeaderView?
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
        let tu = viewModel?.temperatureUnit.value ?? .celsius
        return (lower: tu.customAlertRange.lowerBound, upper: tu.customAlertRange.upperBound)
    }

    private func formatNumber(from value: CGFloat?) -> String {
        guard let value = value else { return "" }
        let number = NSNumber(value: Float(value))
        return numberFormatter.string(from: number) ?? ""
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func latestValue(for type: AlertType) -> String {
        switch type {
        case .temperature:
            if let temp = measurementService?.string(
                for: viewModel?.latestMeasurement.value?.temperature,
                allowSettings: true
            ) {
                return temp
            } else {
                return RuuviLocalization.na
            }
        case .relativeHumidity:
            if let humidity = measurementService?.string(
                for: viewModel?.latestMeasurement.value?.humidity,
                temperature: viewModel?.latestMeasurement.value?.temperature,
                allowSettings: true,
                unit: .percent
            ) {
                return humidity
            } else {
                return RuuviLocalization.na
            }
        case .pressure:
            if let pressure = measurementService?.string(
                for: viewModel?.latestMeasurement.value?.pressure,
                allowSettings: true
            ) {
                return pressure
            } else {
                return RuuviLocalization.na
            }
        case .signal:
            if let signal = viewModel?.latestMeasurement.value?.rssi {
                let symbol = RuuviLocalization.dBm
                return "\(signal)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .aqi:
            let (aqi, _, _) = measurementService.aqi(
                for: viewModel?.latestMeasurement.value?.co2,
                pm25: viewModel?.latestMeasurement.value?.pm25
            )
            return "\(aqi)"
        case .carbonDioxide:
            if let co2 = viewModel?.latestMeasurement.value?.co2?.round(to: 2) {
                let symbol = RuuviLocalization.unitCo2
                return "\(co2)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .pMatter1:
            if let pm1 = viewModel?.latestMeasurement.value?.pm1?.round(to: 2) {
                let symbol = RuuviLocalization.unitPm10
                return "\(pm1)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .pMatter25:
            if let pm25 = viewModel?.latestMeasurement.value?.pm25?.round(to: 2) {
                let symbol = RuuviLocalization.unitPm25
                return "\(pm25)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .pMatter4:
            if let pm4 = viewModel?.latestMeasurement.value?.pm4?.round(to: 2) {
                let symbol = RuuviLocalization.unitPm40
                return "\(pm4)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .pMatter10:
            if let pm10 = viewModel?.latestMeasurement.value?.pm10?.round(to: 2) {
                let symbol = RuuviLocalization.unitPm100
                return "\(pm10)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .voc:
            if let voc = viewModel?.latestMeasurement.value?.voc?.round(to: 2) {
                let symbol = RuuviLocalization.unitVoc
                return "\(voc)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .nox:
            if let nox = viewModel?.latestMeasurement.value?.nox?.round(to: 2) {
                let symbol = RuuviLocalization.unitNox
                return "\(nox)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .soundInstant:
            if let sound = viewModel?.latestMeasurement.value?.dbaInstant?.round(
                to: 2
            ) {
                let symbol = RuuviLocalization.unitSound
                return "\(sound)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        case .luminosity:
            if let luminance = viewModel?.latestMeasurement.value?.luminance?.round(to: 2) {
                let symbol = RuuviLocalization.unitLuminosity
                return "\(luminance)" + " \(symbol)"
            } else {
                return RuuviLocalization.na
            }
        default:
            return RuuviLocalization.na
        }
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
        guard isViewLoaded else {
            return TagSettingsAlertConstants.RelativeHumidity.lowerBound
        }
        let range = HumidityUnit.percent.alertRange
        if let lower = viewModel?.relativeHumidityLowerBound.value {
            return CGFloat(lower)
        } else {
            return CGFloat(range.lowerBound)
        }
    }

    private func humidityUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.RelativeHumidity.upperBound
        }
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
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Pressure.lowerBound
        }
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
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Pressure.upperBound
        }
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
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Signal.lowerBound
        }
        let (minRange, _) = rssiMinMaxForSliders()
        if let lower = viewModel?.signalLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func rssiUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Signal.upperBound
        }
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
            minimum: TagSettingsAlertConstants.Signal.lowerBound,
            maximum: TagSettingsAlertConstants.Signal.upperBound
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

    // AQI
    private func aqiAlertRangeDescription(
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

        if let lower = viewModel?.aqiLowerBound.value,
           let upper = viewModel?.aqiUpperBound.value {
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

    private func aqiLowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.AQI.lowerBound
        }
        let (minRange, _) = aqiAlertRange()
        if let lower = viewModel?.aqiLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func aqiUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.AQI.upperBound
        }
        let (_, maxRange) = aqiAlertRange()
        if let upper = viewModel?.aqiUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func aqiAlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.AQI.lowerBound,
            maximum: TagSettingsAlertConstants.AQI.upperBound
        )
    }

    // Carbon Dioxide
    private func co2AlertRangeDescription(
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

        if let lower = viewModel?.carbonDioxideLowerBound.value,
           let upper = viewModel?.carbonDioxideUpperBound.value {
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

    private func co2LowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.CarbonDioxide.lowerBound
        }
        let (minRange, _) = co2AlertRange()
        if let lower = viewModel?.carbonDioxideLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func co2UpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.CarbonDioxide.upperBound
        }
        let (_, maxRange) = co2AlertRange()
        if let upper = viewModel?.carbonDioxideUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func co2AlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.CarbonDioxide.lowerBound,
            maximum: TagSettingsAlertConstants.CarbonDioxide.upperBound
        )
    }

    // PM1
    private func pm1AlertRangeDescription(
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

        if let lower = viewModel?.pMatter1LowerBound.value,
           let upper = viewModel?.pMatter1UpperBound.value {
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

    private func pm1LowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.lowerBound
        }
        let (minRange, _) = pmAlertRange()
        if let lower = viewModel?.pMatter1LowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func pm1UpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.upperBound
        }
        let (_, maxRange) = pmAlertRange()
        if let upper = viewModel?.pMatter1UpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func pmAlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.ParticulateMatter.lowerBound,
            maximum: TagSettingsAlertConstants.ParticulateMatter.upperBound
        )
    }

    // PM2.5
    private func pm25AlertRangeDescription(
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

        if let lower = viewModel?.pMatter25LowerBound.value,
           let upper = viewModel?.pMatter25UpperBound.value {
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

    private func pm25LowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.lowerBound
        }
        let (minRange, _) = pmAlertRange()
        if let lower = viewModel?.pMatter25LowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func pm25UpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.upperBound
        }
        let (_, maxRange) = pmAlertRange()
        if let upper = viewModel?.pMatter25UpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    // PM4
    private func pm4AlertRangeDescription(
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

        if let lower = viewModel?.pMatter4LowerBound.value,
           let upper = viewModel?.pMatter4UpperBound.value {
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

    private func pm4LowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.lowerBound
        }
        let (minRange, _) = pmAlertRange()
        if let lower = viewModel?.pMatter4LowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func pm4UpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.upperBound
        }
        let (_, maxRange) = pmAlertRange()
        if let upper = viewModel?.pMatter4UpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    // PM10
    private func pm10AlertRangeDescription(
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

        if let lower = viewModel?.pMatter10LowerBound.value,
           let upper = viewModel?.pMatter10UpperBound.value {
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

    private func pm10LowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.lowerBound
        }
        let (minRange, _) = pmAlertRange()
        if let lower = viewModel?.pMatter10LowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func pm10UpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.ParticulateMatter.upperBound
        }
        let (_, maxRange) = pmAlertRange()
        if let upper = viewModel?.pMatter10UpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    // VOC
    private func vocAlertRangeDescription(
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

        if let lower = viewModel?.vocLowerBound.value,
           let upper = viewModel?.vocUpperBound.value {
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

    private func vocLowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.VOC.lowerBound
        }
        let (minRange, _) = vocAlertRange()
        if let lower = viewModel?.vocLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func vocUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.VOC.upperBound
        }
        let (_, maxRange) = vocAlertRange()
        if let upper = viewModel?.vocUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func vocAlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.VOC.lowerBound,
            maximum: TagSettingsAlertConstants.VOC.upperBound
        )
    }

    // NOX
    private func noxAlertRangeDescription(
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

        if let lower = viewModel?.noxLowerBound.value,
           let upper = viewModel?.noxUpperBound.value {
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

    private func noxLowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.NOX.lowerBound
        }
        let (minRange, _) = noxAlertRange()
        if let lower = viewModel?.noxLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func noxUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.NOX.upperBound
        }
        let (_, maxRange) = noxAlertRange()
        if let upper = viewModel?.noxUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func noxAlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.NOX.lowerBound,
            maximum: TagSettingsAlertConstants.NOX.upperBound
        )
    }

    // Sound Instant
    private func soundAlertRangeDescription(
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

        if let lower = viewModel?.soundInstantLowerBound.value,
           let upper = viewModel?.soundInstantUpperBound.value {
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

    private func soundLowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Sound.lowerBound
        }
        let (minRange, _) = soundAlertRange()
        if let lower = viewModel?.soundInstantLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func soundUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Sound.upperBound
        }
        let (_, maxRange) = soundAlertRange()
        if let upper = viewModel?.soundInstantUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func soundAlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.Sound.lowerBound,
            maximum: TagSettingsAlertConstants.Sound.upperBound
        )
    }

    // Luminosity
    private func luminosityAlertRangeDescription(
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

        if let lower = viewModel?.luminosityLowerBound.value,
           let upper = viewModel?.luminosityUpperBound.value {
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

    private func luminosityLowerBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Luminosity.lowerBound
        }
        let (minRange, _) = luminosityAlertRange()
        if let lower = viewModel?.luminosityLowerBound.value {
            return CGFloat(lower)
        } else {
            return minRange
        }
    }

    private func luminosityUpperBound() -> CGFloat {
        guard isViewLoaded else {
            return TagSettingsAlertConstants.Luminosity.upperBound
        }
        let (_, maxRange) = luminosityAlertRange()
        if let upper = viewModel?.luminosityUpperBound.value {
            return CGFloat(upper)
        } else {
            return maxRange
        }
    }

    private func luminosityAlertRange() -> (
        minimum: CGFloat,
        maximum: CGFloat
    ) {
        (
            minimum: TagSettingsAlertConstants.Luminosity.lowerBound,
            maximum: TagSettingsAlertConstants.Luminosity.upperBound
        )
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
}

extension TagSettingsViewController: TagSettingsAlertConfigCellDelegate {

    // swiftlint:disable:next cyclomatic_complexity
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
        case aqiAlertCell:
            description = viewModel?.aqiAlertDescription.value
        case co2AlertCell:
            description = viewModel?.carbonDioxideAlertDescription.value
        case pm1AlertCell:
            description = viewModel?.pMatter1AlertDescription.value
        case pm25AlertCell:
            description = viewModel?.pMatter25AlertDescription.value
        case pm4AlertCell:
            description = viewModel?.pMatter4AlertDescription.value
        case pm10AlertCell:
            description = viewModel?.pMatter10AlertDescription.value
        case vocAlertCell:
            description = viewModel?.vocAlertDescription.value
        case noxAlertCell:
            description = viewModel?.noxAlertDescription.value
        case soundInstantAlertCell:
            description = viewModel?.soundInstantAlertDescription.value
        case luminosityAlertCell:
            description = viewModel?.luminosityAlertDescription.value
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

    // swiftlint:disable:next cyclomatic_complexity
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
        case aqiAlertCell:
            showAQIAlertSetDialog(sender: sender)
        case co2AlertCell:
            showCo2AlertSetDialog(sender: sender)
        case pm1AlertCell:
            showPM1AlertSetDialog(sender: sender)
        case pm25AlertCell:
            showPM25AlertSetDialog(sender: sender)
        case pm4AlertCell:
            showPM4AlertSetDialog(sender: sender)
        case pm10AlertCell:
            showPM10AlertSetDialog(sender: sender)
        case vocAlertCell:
            showVOCAlertSetDialog(sender: sender)
        case noxAlertCell:
            showNOXAlertSetDialog(sender: sender)
        case soundInstantAlertCell:
            showSoundAlertSetDialog(sender: sender)
        case luminosityAlertCell:
            showLuminosityAlertSetDialog(sender: sender)
        case cloudConnectionAlertCell:
            showCloudConnectionAlertSetDialog(sender: sender)
        default:
            break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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

        case aqiAlertCell:
            output.viewDidChangeAlertState(
                for: .aqi(lower: 0, upper: 0),
                isOn: isOn
            )

        case co2AlertCell:
            output.viewDidChangeAlertState(
                for: .carbonDioxide(lower: 0, upper: 0),
                isOn: isOn
            )

        case pm1AlertCell:
            output.viewDidChangeAlertState(
                for: .pMatter1(lower: 0, upper: 0),
                isOn: isOn
            )

        case pm25AlertCell:
            output.viewDidChangeAlertState(
                for: .pMatter25(lower: 0, upper: 0),
                isOn: isOn
            )

        case pm4AlertCell:
            output.viewDidChangeAlertState(
                for: .pMatter4(lower: 0, upper: 0),
                isOn: isOn
            )

        case pm10AlertCell:
            output.viewDidChangeAlertState(
                for: .pMatter10(lower: 0, upper: 0),
                isOn: isOn
            )

        case vocAlertCell:
            output.viewDidChangeAlertState(
                for: .voc(lower: 0, upper: 0),
                isOn: isOn
            )

        case noxAlertCell:
            output.viewDidChangeAlertState(
                for: .nox(lower: 0, upper: 0),
                isOn: isOn
            )

        case soundInstantAlertCell:
            output.viewDidChangeAlertState(
                for: .soundInstant(lower: 0, upper: 0),
                isOn: isOn
            )

        case luminosityAlertCell:
            output.viewDidChangeAlertState(
                for: .luminosity(lower: 0, upper: 0),
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

        case aqiAlertCell:
            if minValue != viewModel?.aqiLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .aqi(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.aqiUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .aqi(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case co2AlertCell:
            if minValue != viewModel?.carbonDioxideLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .carbonDioxide(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.carbonDioxideUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .carbonDioxide(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case pm1AlertCell:
            if minValue != viewModel?.pMatter1LowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .pMatter1(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.pMatter1UpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .pMatter1(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case pm25AlertCell:
            if minValue != viewModel?.pMatter25LowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .pMatter25(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.pMatter25UpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .pMatter25(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case pm4AlertCell:
            if minValue != viewModel?.pMatter4LowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .pMatter4(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.pMatter4UpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .pMatter4(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case pm10AlertCell:
            if minValue != viewModel?.pMatter10LowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .pMatter10(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.pMatter1UpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .pMatter10(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case vocAlertCell:
            if minValue != viewModel?.vocLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .voc(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.vocUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .voc(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case noxAlertCell:
            if minValue != viewModel?.noxLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .nox(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.noxUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .nox(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case soundInstantAlertCell:
            if minValue != viewModel?.soundInstantLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .soundInstant(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.soundInstantUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .soundInstant(lower: 0, upper: 0),
                    upper: maxValue
                )
            }

        case luminosityAlertCell:
            if minValue != viewModel?.luminosityLowerBound.value {
                output.viewDidChangeAlertLowerBound(
                    for: .luminosity(lower: 0, upper: 0),
                    lower: minValue
                )
            }

            if maxValue != viewModel?.luminosityUpperBound.value {
                output.viewDidChangeAlertUpperBound(
                    for: .luminosity(lower: 0, upper: 0),
                    upper: maxValue
                )
            }
        default:
            break
        }
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
        case aqiAlertCell:
            aqiAlertCell?.setAlertLimitDescription(
                description: aqiAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case co2AlertCell:
            co2AlertCell?.setAlertLimitDescription(
                description: co2AlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case pm1AlertCell:
            pm1AlertCell?.setAlertLimitDescription(
                description: pm1AlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case pm25AlertCell:
            pm25AlertCell?.setAlertLimitDescription(
                description: pm25AlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case pm4AlertCell:
            pm4AlertCell?.setAlertLimitDescription(
                description: pm4AlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case pm10AlertCell:
            pm10AlertCell?.setAlertLimitDescription(
                description: pm10AlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case vocAlertCell:
            vocAlertCell?.setAlertLimitDescription(
                description: vocAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case noxAlertCell:
            noxAlertCell?.setAlertLimitDescription(
                description: noxAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case soundInstantAlertCell:
            soundInstantAlertCell?.setAlertLimitDescription(
                description: soundAlertRangeDescription(
                    from: minValue,
                    max: maxValue
                ))
        case luminosityAlertCell:
            luminosityAlertCell?.setAlertLimitDescription(
                description: luminosityAlertRangeDescription(
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

    private func showAQIAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.aqi
        let (minimumRange, maximumRange) = aqiAlertRange()
        let (minimumValue, maximumValue) = aqiValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showCo2AlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.Co2AlertTitleLabel.text(
            RuuviLocalization.unitCo2
        )

        let (minimumRange, maximumRange) = co2AlertRange()
        let (minimumValue, maximumValue) = co2Value()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showPM1AlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.Pm10AlertTitleLabel.text(
            RuuviLocalization.unitPm10
        )

        let (minimumRange, maximumRange) = pmAlertRange()
        let (minimumValue, maximumValue) = pm1Value()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showPM25AlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.Pm25AlertTitleLabel.text(
            RuuviLocalization.unitPm25
        )

        let (minimumRange, maximumRange) = pmAlertRange()
        let (minimumValue, maximumValue) = pm25Value()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showPM4AlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.Pm40AlertTitleLabel.text(
            RuuviLocalization.unitPm40
        )

        let (minimumRange, maximumRange) = pmAlertRange()
        let (minimumValue, maximumValue) = pm4Value()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showPM10AlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.Pm100AlertTitleLabel.text(
            RuuviLocalization.unitPm100
        )

        let (minimumRange, maximumRange) = pmAlertRange()
        let (minimumValue, maximumValue) = pm10Value()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showVOCAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.VocAlertTitleLabel.text(
            RuuviLocalization.unitVoc
        )

        let (minimumRange, maximumRange) = vocAlertRange()
        let (minimumValue, maximumValue) = vocValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showNOXAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.NoxAlertTitleLabel.text(
            RuuviLocalization.unitNox
        )

        let (minimumRange, maximumRange) = noxAlertRange()
        let (minimumValue, maximumValue) = noxValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showSoundAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.SoundAlertTitleLabel.text(
            RuuviLocalization.unitSound
        )

        let (minimumRange, maximumRange) = soundAlertRange()
        let (minimumValue, maximumValue) = soundInstantValue()
        showSensorCustomAlertRangeDialog(
            title: title,
            minimumBound: minimumRange,
            maximumBound: maximumRange,
            currentLowerBound: minimumValue,
            currentUpperBound: maximumValue,
            sender: sender
        )
    }

    private func showLuminosityAlertSetDialog(sender: TagSettingsAlertConfigCell) {
        let title = RuuviLocalization.TagSettings.LuminosityAlertTitleLabel.text(
            RuuviLocalization.unitLuminosity
        )

        let (minimumRange, maximumRange) = luminosityAlertRange()
        let (minimumValue, maximumValue) = luminosityValue()
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

        let minimumDuration = TagSettingsAlertConstants.CloudConnection.minUnseenDuration
        let defaultDuration = TagSettingsAlertConstants.CloudConnection.defaultUnseenDuration
        let currentDuration = viewModel?.cloudConnectionAlertUnseenDuration.value?.intValue ?? defaultDuration

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

    private func rssiAlertRange() -> (minimum: Double, maximum: Double) {
        (
            minimum: TagSettingsAlertConstants.Signal.lowerBound,
            maximum: TagSettingsAlertConstants.Signal.upperBound
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

    // AQI
    private func aqiValue() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.aqiLowerBound.value,
           let upper = viewModel?.aqiUpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // Carbon Dioxide
    private func co2Value() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.carbonDioxideLowerBound.value,
           let upper = viewModel?.carbonDioxideUpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // PM1
    private func pm1Value() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.pMatter1LowerBound.value,
           let upper = viewModel?.pMatter1UpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // PM1
    private func pm25Value() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.pMatter25LowerBound.value,
           let upper = viewModel?.pMatter25UpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // PM1
    private func pm4Value() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.pMatter4LowerBound.value,
           let upper = viewModel?.pMatter4UpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // PM10
    private func pm10Value() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.pMatter10LowerBound.value,
           let upper = viewModel?.pMatter10UpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // VOC
    private func vocValue() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.vocLowerBound.value,
           let upper = viewModel?.vocUpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // NOX
    private func noxValue() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.noxLowerBound.value,
           let upper = viewModel?.noxUpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // Sound Instant
    private func soundInstantValue() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.soundInstantLowerBound.value,
           let upper = viewModel?.soundInstantUpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
        }
    }

    // Luminosity
    private func luminosityValue() -> (minimum: Double?, maximum: Double?) {
        if let lower = viewModel?.luminosityLowerBound.value,
           let upper = viewModel?.luminosityUpperBound.value {
            return (minimum: lower, maximum: upper)
        } else {
            return (minimum: nil, maximum: nil)
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
            moreInfoDataFormatCell.bind(viewModel.version) { [weak self] cell, version in
                guard let sSelf = self else { return }
                cell.configure(value: sSelf.formattedVersion(value: version))
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
            moreInfoRSSICell.bind(viewModel.latestMeasurement) {
              [weak self] cell, _ in
              cell.configure(value: self?.latestValue(for: .signal(lower: 0, upper: 0)))
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

        // Common
        var moreInfoCells: [TagSettingsItem] = [
            moreInfoMacAddressItem(),
            moreInfoDataFormatItem(),
            moreInfoDataSourceItem(),
            moreInfoBatteryVoltageItem(),
        ]

        // Variable items
        if viewModel?.accelerationX.value != nil {
            moreInfoCells.append(moreInfoAccXItem())
        }

        if viewModel?.accelerationY.value != nil {
            moreInfoCells.append(moreInfoAccYItem())
        }

        if viewModel?.accelerationZ.value != nil {
            moreInfoCells.append(moreInfoAccZItem())
        }

        if viewModel?.txPower.value != nil {
            moreInfoCells.append(moreInfoTxPowerItem())
        }

        // Common
        moreInfoCells += [
            moreInfoRSSIItem(),
            moreInfoMeasurementSequenceItem(),
        ]

        let section = TagSettingsSection(
            identifier: .moreInfo,
            title: RuuviLocalization.TagSettings.Label.MoreInfo.text.capitalized,
            cells: moreInfoCells,
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
                    value: self?.formattedVersion(value: self?.viewModel?.version.value)
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
            action: { [weak self] _ in
                self?.output.viewDidTapOnTxPower()
            }
        )
        return settingItem
    }

    private func moreInfoRSSIItem() -> TagSettingsItem {
        var rssi: String = ""
        if let signal = viewModel?.rssi.value?.stringValue {
          let symbol = RuuviLocalization.dBm
          rssi = "\(signal)" + " \(symbol)"
        } else {
          rssi = latestValue(for: .signal(lower: 0, upper: 0))
        }
        let settingItem = TagSettingsItem(
            createdCell: { [weak self] in
                self?.moreInfoRSSICell?.configure(
                    title: RuuviLocalization.TagSettings.RssiTitleLabel.text,
                    value: rssi
                )
                return self?.moreInfoRSSICell ?? UITableViewCell()
            },
            action: nil
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
            case .advertisement, .bgAdvertisement:
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

    private func formattedVersion(value: Int?) -> String {
        if value == 0xC5 {
            return "C5"
        } else if value == 0xE1 {
            return "E1"
        } else if value == 0x06 {
            return "6"
        } else {
            return value.stringValue
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

    func tableView(_: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        let sectionItem = tableViewSections[section]
        switch sectionItem.headerType {
        case .simple:
            switch sectionItem.identifier {
            case .general:
                return 0
            default:
                return commonHeaderHeight
            }
        default:
            return commonHeaderHeight
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func tableView(
        _: UITableView,
        viewForHeaderInSection section: Int
    ) -> UIView? {
        let sectionItem = tableViewSections[section]
        switch sectionItem.headerType {
        case .simple:
            switch sectionItem.identifier {
            case .general:
                return nil
            default:
                let view = TagSettingsSimpleSectionHeader()
                view.setTitle(
                    with: sectionItem.title,
                    section: section
                )
                return view
            }

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
            case .alertAQI:
                return alertSectionHeaderView(
                    from: aqiAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.aqiAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isAQIAlertOn.value
                    ),
                    alertState: viewModel?.aqiAlertState.value,
                    section: section
                )
            case .alertCarbonDioxide:
                return alertSectionHeaderView(
                    from: co2AlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.carbonDioxideAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isCarbonDioxideAlertOn.value
                    ),
                    alertState: viewModel?.carbonDioxideAlertState.value,
                    section: section
                )
            case .alertPMatter1:
                return alertSectionHeaderView(
                    from: pm1AlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.pMatter1AlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isPMatter1AlertOn.value
                    ),
                    alertState: viewModel?.pMatter1AlertState.value,
                    section: section
                )
            case .alertPMatter25:
                return alertSectionHeaderView(
                    from: pm25AlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.pMatter25AlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isPMatter25AlertOn.value
                    ),
                    alertState: viewModel?.pMatter25AlertState.value,
                    section: section
                )
            case .alertPMatter4:
                return alertSectionHeaderView(
                    from: pm4AlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.pMatter4AlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isPMatter4AlertOn.value
                    ),
                    alertState: viewModel?.pMatter4AlertState.value,
                    section: section
                )
            case .alertPMatter10:
                return alertSectionHeaderView(
                    from: pm10AlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.pMatter10AlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isPMatter10AlertOn.value
                    ),
                    alertState: viewModel?.pMatter10AlertState.value,
                    section: section
                )
            case .alertVOC:
                return alertSectionHeaderView(
                    from: vocAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.vocAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isVOCAlertOn.value
                    ),
                    alertState: viewModel?.vocAlertState.value,
                    section: section
                )
            case .alertNOx:
                return alertSectionHeaderView(
                    from: noxAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.noxAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isNOXAlertOn.value
                    ),
                    alertState: viewModel?.noxAlertState.value,
                    section: section
                )
            case .alertSoundInstant:
                return alertSectionHeaderView(
                    from: soundInstantAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.soundInstantAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isSoundInstantAlertOn.value
                    ),
                    alertState: viewModel?.soundInstantAlertState.value,
                    section: section
                )
            case .alertLuminosity:
                return alertSectionHeaderView(
                    from: luminosityAlertSectionHeaderView,
                    sectionItem: sectionItem,
                    mutedTill: viewModel?.luminosityAlertMutedTill.value,
                    isAlertOn: alertsAvailable() && GlobalHelpers.getBool(
                        from: viewModel?.isLuminosityAlertOn.value
                    ),
                    alertState: viewModel?.luminosityAlertState.value,
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
        case .alertAQI:
            reloadAQIAlertSectionHeader()
        case .alertCarbonDioxide:
            reloadCo2AlertSectionHeader()
        case .alertPMatter1:
            reloadPM1AlertSectionHeader()
        case .alertPMatter25:
            reloadPM25AlertSectionHeader()
        case .alertPMatter4:
            reloadPM4AlertSectionHeader()
        case .alertPMatter10:
            reloadPM10AlertSectionHeader()
        case .alertVOC:
            reloadVOCAlertSectionHeader()
        case .alertNOx:
            reloadNOXAlertSectionHeader()
        case .alertSoundInstant:
            reloadSoundInstantAlertSectionHeader()
        case .alertLuminosity:
            reloadLuminosityAlertSectionHeader()
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
                    let latest = latestValue(for: .temperature(lower: 0, upper: 0))
                    temperatureAlertCell.setAlertLimitDescription(description: temperatureAlertRangeDescription())
                    temperatureAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: temperatureLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: temperatureUpperBound()
                    )
                    temperatureAlertCell.setLatestMeasurementText(with: latest)
                    temperatureAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(from: !hasMeasurement()),
                        identifier: currentSection.identifier
                    )
                }
            case .alertHumidity:
                if let humidityAlertCell {
                    let (minRange, maxRange) = humidityMinMaxForSliders()
                    let latest = latestValue(for: .relativeHumidity(lower: 0, upper: 0))
                    humidityAlertCell.setAlertLimitDescription(description: humidityAlertRangeDescription())
                    humidityAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: humidityLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: humidityUpperBound()
                    )
                    humidityAlertCell.setLatestMeasurementText(with: latest)
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
                    let latest = latestValue(for: .pressure(lower: 0, upper: 0))
                    pressureAlertCell.setAlertLimitDescription(description: pressureAlertRangeDescription())
                    pressureAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: pressureLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: pressureUpperBound()
                    )
                    pressureAlertCell.setLatestMeasurementText(with: latest)
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
                    let latest = latestValue(for: .signal(lower: 0, upper: 0))
                    rssiAlertCell.setAlertLimitDescription(description: rssiAlertRangeDescription())
                    rssiAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: rssiLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: rssiUpperBound()
                    )
                    rssiAlertCell.setLatestMeasurementText(with: latest)
                    rssiAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(from: !hasMeasurement()) ||
                            !GlobalHelpers.getBool(from: viewModel?.isClaimedTag.value),
                        identifier: currentSection.identifier
                    )
                }
            case .alertAQI:
                if let aqiAlertCell {
                    let (minRange, maxRange) = aqiAlertRange()
                    let latest = latestValue(
                        for: .aqi(lower: 0, upper: 0)
                    )
                    aqiAlertCell
                        .setAlertLimitDescription(
                            description: aqiAlertRangeDescription()
                        )
                    aqiAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: aqiLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: aqiUpperBound()
                    )
                    aqiAlertCell.setLatestMeasurementText(with: latest)
                    aqiAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertCarbonDioxide:
                if let co2AlertCell {
                    let (minRange, maxRange) = co2AlertRange()
                    let latest = latestValue(
                        for: .carbonDioxide(lower: 0, upper: 0)
                    )
                    co2AlertCell
                        .setAlertLimitDescription(
                            description: co2AlertRangeDescription()
                        )
                    co2AlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: co2LowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: co2UpperBound()
                    )
                    co2AlertCell.setLatestMeasurementText(with: latest)
                    co2AlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertPMatter1:
                if let pm1AlertCell {
                    let (minRange, maxRange) = pmAlertRange()
                    let latest = latestValue(
                        for: .pMatter1(lower: 0, upper: 0)
                    )
                    pm1AlertCell
                        .setAlertLimitDescription(
                            description: pm1AlertRangeDescription()
                        )
                    pm1AlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: pm1LowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: pm1UpperBound()
                    )
                    pm1AlertCell.setLatestMeasurementText(with: latest)
                    pm1AlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertPMatter25:
                if let pm25AlertCell {
                    let (minRange, maxRange) = pmAlertRange()
                    let latest = latestValue(
                        for: .pMatter25(lower: 0, upper: 0)
                    )
                    pm25AlertCell
                        .setAlertLimitDescription(
                            description: pm25AlertRangeDescription()
                        )
                    pm25AlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: pm25LowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: pm25UpperBound()
                    )
                    pm25AlertCell.setLatestMeasurementText(with: latest)
                    pm25AlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertPMatter4:
                if let pm4AlertCell {
                    let (minRange, maxRange) = pmAlertRange()
                    let latest = latestValue(
                        for: .pMatter4(lower: 0, upper: 0)
                    )
                    pm4AlertCell
                        .setAlertLimitDescription(
                            description: pm4AlertRangeDescription()
                        )
                    pm4AlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: pm4LowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: pm4UpperBound()
                    )
                    pm4AlertCell.setLatestMeasurementText(with: latest)
                    pm4AlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertPMatter10:
                if let pm10AlertCell {
                    let (minRange, maxRange) = pmAlertRange()
                    let latest = latestValue(
                        for: .pMatter10(lower: 0, upper: 0)
                    )
                    pm10AlertCell
                        .setAlertLimitDescription(
                            description: pm10AlertRangeDescription()
                        )
                    pm10AlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: pm10LowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: pm10UpperBound()
                    )
                    pm10AlertCell.setLatestMeasurementText(with: latest)
                    pm10AlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertVOC:
                if let vocAlertCell {
                    let (minRange, maxRange) = vocAlertRange()
                    let latest = latestValue(
                        for: .voc(lower: 0, upper: 0)
                    )
                    vocAlertCell
                        .setAlertLimitDescription(
                            description: vocAlertRangeDescription()
                        )
                    vocAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: vocLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: vocUpperBound()
                    )
                    vocAlertCell.setLatestMeasurementText(with: latest)
                    vocAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertNOx:
                if let noxAlertCell {
                    let (minRange, maxRange) = noxAlertRange()
                    let latest = latestValue(
                        for: .nox(lower: 0, upper: 0)
                    )
                    noxAlertCell
                        .setAlertLimitDescription(
                            description: noxAlertRangeDescription()
                        )
                    noxAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: noxLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: noxUpperBound()
                    )
                    noxAlertCell.setLatestMeasurementText(with: latest)
                    noxAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertSoundInstant:
                if let soundInstantAlertCell {
                    let (minRange, maxRange) = soundAlertRange()
                    let latest = latestValue(
                        for: .soundInstant(lower: 0, upper: 0)
                    )
                    soundInstantAlertCell
                        .setAlertLimitDescription(
                            description: soundAlertRangeDescription()
                        )
                    soundInstantAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: soundLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: soundUpperBound()
                    )
                    soundInstantAlertCell.setLatestMeasurementText(with: latest)
                    soundInstantAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
                        identifier: currentSection.identifier
                    )
                }
            case .alertLuminosity:
                if let luminosityAlertCell {
                    let (minRange, maxRange) = luminosityAlertRange()
                    let latest = latestValue(
                        for: .luminosity(lower: 0, upper: 0)
                    )
                    luminosityAlertCell
                        .setAlertLimitDescription(
                            description: luminosityAlertRangeDescription()
                        )
                    luminosityAlertCell.setAlertRange(
                        minValue: minRange,
                        selectedMinValue: luminosityLowerBound(),
                        maxValue: maxRange,
                        selectedMaxValue: luminosityUpperBound()
                    )
                    luminosityAlertCell.setLatestMeasurementText(with: latest)
                    luminosityAlertCell.disableEditing(
                        disable: GlobalHelpers.getBool(
                            from: !hasMeasurement()
                        ),
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
            case .moreInfo:
              if let moreInfoRSSICell {
                let signal = latestValue(for: .signal(lower: 0, upper: 0))
                moreInfoRSSICell.configure(value: signal)
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

    // swiftlint:disable:next cyclomatic_complexity function_body_length
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
        case aqiAlertCell:
            output.viewDidChangeAlertDescription(
                for: .aqi(lower: 0, upper: 0),
                description: inputText
            )
        case co2AlertCell:
            output.viewDidChangeAlertDescription(
                for: .carbonDioxide(lower: 0, upper: 0),
                description: inputText
            )
        case pm1AlertCell:
            output.viewDidChangeAlertDescription(
                for: .pMatter1(lower: 0, upper: 0),
                description: inputText
            )
        case pm25AlertCell:
            output.viewDidChangeAlertDescription(
                for: .pMatter25(lower: 0, upper: 0),
                description: inputText
            )
        case pm4AlertCell:
            output.viewDidChangeAlertDescription(
                for: .pMatter4(lower: 0, upper: 0),
                description: inputText
            )
        case pm10AlertCell:
            output.viewDidChangeAlertDescription(
                for: .pMatter10(lower: 0, upper: 0),
                description: inputText
            )
        case vocAlertCell:
            output.viewDidChangeAlertDescription(
                for: .voc(lower: 0, upper: 0),
                description: inputText
            )
        case noxAlertCell:
            output.viewDidChangeAlertDescription(
                for: .nox(lower: 0, upper: 0),
                description: inputText
            )
        case soundInstantAlertCell:
            output.viewDidChangeAlertDescription(
                for: .soundInstant(lower: 0, upper: 0),
                description: inputText
            )
        case luminosityAlertCell:
            output.viewDidChangeAlertDescription(
                for: .luminosity(lower: 0, upper: 0),
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
            if sender == temperatureAlertCell || sender == humidityAlertCell ||
                sender == pressureAlertCell || sender == rssiAlertCell ||
                sender == co2AlertCell || sender == co2AlertCell ||
                sender == pm1AlertCell ||
                sender == pm25AlertCell || sender == pm4AlertCell ||
                sender == pm10AlertCell || sender == vocAlertCell ||
                sender == noxAlertCell || sender == soundInstantAlertCell ||
                sender == luminosityAlertCell {
                alertTextField.text = measurementService.string(
                    from: currentLowerBound
                )
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
            if minimumBound < 0 {
                alertMaxRangeTextField.addNumericAccessory()
            }
            if sender == temperatureAlertCell || sender == humidityAlertCell ||
                sender == pressureAlertCell || sender == rssiAlertCell ||
                sender == co2AlertCell ||
                sender == co2AlertCell || sender == pm1AlertCell ||
                sender == pm25AlertCell || sender == pm4AlertCell ||
                sender == pm10AlertCell || sender == vocAlertCell ||
                sender == noxAlertCell || sender == soundInstantAlertCell ||
                sender == luminosityAlertCell {
                alertTextField.text = measurementService.string(
                    from: currentUpperBound
                )
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

            guard minimumInputText.doubleValue < maximumInputText.doubleValue else {
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

            let currentDuration = viewModel?.cloudConnectionAlertUnseenDuration.value?.intValue ??
                    TagSettingsAlertConstants.CloudConnection.defaultUnseenDuration
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
