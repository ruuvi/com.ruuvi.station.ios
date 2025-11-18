import UIKit
import SwiftUI
import Combine
import RuuviLocalization
import RuuviOntology

@MainActor
final class CardsSettingsState: ObservableObject {
    // MARK: - Published properties exposed to SwiftUI
    @Published private(set) var name: String
    @Published private(set) var ownerName: String
    @Published private(set) var showOwner: Bool
    @Published private(set) var showOwnersPlan: Bool
    @Published private(set) var ownersPlan: String
    @Published private(set) var showShare: Bool
    @Published private(set) var shareSummary: String
    @Published private(set) var visibleMeasurementsValue: String?
    @Published private(set) var showVisibleMeasurementsRow: Bool = false
    @Published private(set) var backgroundImage: Image?
    @Published private(set) var moreInfoRows: [MoreInfoRowModel]
    @Published private(set) var firmwareVersion: String
    @Published private(set) var keepConnectionStatusText: String = ""
    @Published private(set) var isKeepConnectionOn: Bool = false
    @Published private(set) var isKeepConnectionInProgress: Bool = false
    @Published private(set) var keepConnectionDescription: String =
            RuuviLocalization.TagSettings.PairAndBackgroundScan.description
    @Published private(set) var isKeepConnectionToggleEnabled: Bool = true
    @Published private(set) var showKeepConnectionStatusLabel: Bool = true

    // Offset correction reactive properties
    @Published private(set) var temperatureOffset: String = ""
    @Published private(set) var humidityOffset: String = ""
    @Published private(set) var pressureOffset: String = ""
    @Published private(set) var showHumidityOffset: Bool = false
    @Published private(set) var showPressureOffset: Bool = false
    @Published private(set) var hasLatestMeasurement: Bool = false
    @Published private(set) var alertSections: [AlertSectionModel] = []

    // MARK: - State management
    @Published var expandedSections: Set<String> = []
    @Published var expandedAlertSections: Set<String> = []
    @Published private(set) var lastExpandedSectionID: String?
    @Published private(set) var lastExpandedAlertID: String?

    // MARK: - Snapshot reference
    private(set) var snapshot: RuuviTagCardSnapshot
    private var cancellables = Set<AnyCancellable>()
    private var connectionDisplayFrozen = false

    init(snapshot: RuuviTagCardSnapshot) {
        self.snapshot = snapshot
        self.name = ""
        self.ownerName = ""
        self.showOwner = false
        self.showOwnersPlan = false
        self.ownersPlan = ""
        self.showShare = false
        self.shareSummary = ""
        self.backgroundImage = nil
        self.moreInfoRows = []
        self.firmwareVersion = ""
        self.keepConnectionDescription = RuuviLocalization.TagSettings.PairAndBackgroundScan.description
        populate(from: snapshot)
        bind(to: snapshot)
    }

    func update(with snapshot: RuuviTagCardSnapshot) {
        cancellables.removeAll()
        self.snapshot = snapshot
        populate(from: snapshot)
        bind(to: snapshot)
    }

    private func populate(from snapshot: RuuviTagCardSnapshot) {
        name = snapshot.displayData.name
        ownerName = snapshot.ownership.ownerName.unwrapped
        showOwner = snapshot.ownership.isAuthorized
        showOwnersPlan = CardsSettingsState.shouldShowOwnersPlan(
            ownership: snapshot.ownership,
            metadata: snapshot.metadata
        )
        ownersPlan = snapshot.ownership.ownersPlan.unwrapped
        showShare = snapshot.metadata.canShareTag
        shareSummary = Self.calculateShareSummary(from: snapshot)
        backgroundImage = snapshot.displayData.background.map { Image(uiImage: $0) }
        moreInfoRows = Self.buildMoreInfoRows(from: snapshot)
        firmwareVersion = snapshot.displayData.firmwareVersion.unwrapped
        applyConnectionData(snapshot.connectionData)
        showKeepConnectionStatusLabel = !snapshot.capabilities.hideSwitchStatusLabel
        temperatureOffset = snapshot.calibration.temperatureOffset.unwrapped
        humidityOffset = snapshot.calibration.humidityOffset.unwrapped
        pressureOffset = snapshot.calibration.pressureOffset.unwrapped
        showHumidityOffset = snapshot.calibration.isHumidityOffsetVisible
        showPressureOffset = snapshot.calibration.isPressureOffsetVisible
        hasLatestMeasurement = snapshot.latestRawRecord != nil
    }

    // swiftlint:disable:next function_body_length
    private func bind(to snapshot: RuuviTagCardSnapshot) {
        snapshot.$displayData
            .map(\.name)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)

        snapshot.$ownership
            .map { $0.ownerName.unwrapped }
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$ownerName)

        snapshot.$ownership
            .map { $0.isAuthorized }
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$showOwner)

        snapshot.$ownership
            .map { $0.ownersPlan.unwrapped }
            .removeDuplicates { $0 == $1 }
            .receive(on: DispatchQueue.main)
            .assign(to: &$ownersPlan)

        // Add binding for share summary
        snapshot.$ownership
            .map { ownership in
                Self.calculateShareSummary(
                    sharedTo: ownership.sharedTo,
                    maxShareCount: ownership.maxShareCount
                )
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$shareSummary)

        snapshot.$ownership
            .combineLatest(snapshot.$metadata)
            .map { ownership, metadata in
                CardsSettingsState.shouldShowOwnersPlan(
                    ownership: ownership,
                    metadata: metadata
                )
            }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showOwnersPlan)

        snapshot.$metadata
            .map(\.canShareTag)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showShare)

        snapshot.$displayData
            .map(\.background)
            .removeDuplicates { $0 === $1 }
            .map { $0.map { Image(uiImage: $0) } }
            .receive(on: DispatchQueue.main)
            .assign(to: &$backgroundImage)

        snapshot.$displayData
            .map { $0.firmwareVersion ?? RuuviLocalization.na }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$firmwareVersion)

        snapshot.$displayData
            .sink { [weak self] _ in
                self?.refreshMoreInfoRows()
            }
            .store(in: &cancellables)

        snapshot.$capabilities
            .sink { [weak self] _ in
                self?.refreshMoreInfoRows()
            }
            .store(in: &cancellables)

        snapshot.$metadata
            .sink { [weak self] _ in
                self?.refreshMoreInfoRows()
            }
            .store(in: &cancellables)

        snapshot.$connectionData
            .sink { [weak self] connectionData in
                self?.applyConnectionData(connectionData)
            }
            .store(in: &cancellables)

        snapshot.$capabilities
            .map { !$0.hideSwitchStatusLabel }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showKeepConnectionStatusLabel)

        // Bind to calibration changes for offset correction
        snapshot.$calibration
            .map(\.temperatureOffset.unwrapped)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$temperatureOffset)

        snapshot.$calibration
            .map(\.humidityOffset.unwrapped)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$humidityOffset)

        snapshot.$calibration
            .map(\.pressureOffset.unwrapped)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$pressureOffset)

        snapshot.$calibration
            .map(\.isHumidityOffsetVisible)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showHumidityOffset)

        snapshot.$calibration
            .map(\.isPressureOffsetVisible)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showPressureOffset)

        // Bind to latest measurement changes
        snapshot.$latestRawRecord
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasLatestMeasurement)

    }

    // MARK: Public

    // MARK: - Offset Correction
    var showOffsetCorrection: Bool {
        let isOwner = snapshot.metadata.isOwner
        let isCloud = snapshot.metadata.isCloud
        // Show offset correction unless it's a cloud sensor and user is not the owner
        return !(isCloud && !isOwner)
    }

    var isHumidityOffsetVisible: Bool {
        snapshot.calibration.isHumidityOffsetVisible
    }

    var isPressureOffsetVisible: Bool {
        snapshot.calibration.isPressureOffsetVisible
    }

    var showBluetoothSection: Bool {
        snapshot.capabilities.showKeepConnection
    }

    var shouldShowNoValuesIndicator: Bool {
        if let version = snapshot.displayData.version {
            return version < 5
        }
        return false
    }

    func updateVisibleMeasurementsSummary(
        value: String?,
        isVisible: Bool
    ) {
        visibleMeasurementsValue = value
        showVisibleMeasurementsRow = isVisible
    }

    // MARK: - Settings Sections
    public var settingsSections: [SettingsSection] {
        var sections: [SettingsSection] = []

        // Offset Correction section - only show if user can edit it
        if showOffsetCorrection {
            sections.append(
                SettingsSection(
                    id: "offsetCorrection",
                    title: RuuviLocalization.offsetCorrection,
                    content: { AnyView(OffsetCorrectionView()) }
                )
            )
        }

        // More Info section
        sections.append(
            SettingsSection(
                id: "moreInfo",
                title: RuuviLocalization.moreInfo,
                content: { AnyView(MoreInfoView()) }
            )
        )

        // Firmware Update section
        sections.append(
            SettingsSection(
                id: "firmwareUpdate",
                title: RuuviLocalization.firmware,
                content: { AnyView(FirmwareSectionView()) }
            )
        )

        // Remove section
        sections.append(
            SettingsSection(
                id: "remove",
                title: RuuviLocalization.remove,
                content: { AnyView(RemoveSectionView()) }
            )
        )

        return sections
    }

    // MARK: - Actions
    func toggleSection(_ id: String) {
        withAnimation(.easeInOut(duration: 0.25)) {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
                lastExpandedSectionID = nil
            } else {
                expandedSections.insert(id)
                lastExpandedSectionID = id
            }
        }
    }

    func toggleAlertSection(_ id: String) {
        if expandedAlertSections.contains(id) {
            expandedAlertSections.remove(id)
            lastExpandedAlertID = nil
        } else {
            expandedAlertSections.insert(id)
            lastExpandedAlertID = id
        }
    }

    func isAlertSectionExpanded(_ id: String) -> Bool {
        expandedAlertSections.contains(id)
    }

    func clearLastExpandedSectionID() {
        lastExpandedSectionID = nil
    }

    func clearLastExpandedAlertID() {
        lastExpandedAlertID = nil
    }
}

// MARK: Private helpers
private extension CardsSettingsState {
    struct ConnectionDisplayState {
        var title: String
        var isOn: Bool
        var isInProgress: Bool
        var isToggleEnabled: Bool
    }

    static func shouldShowOwnersPlan(
        ownership: RuuviTagCardSnapshotOwnership,
        metadata: RuuviTagCardSnapshotMetadata
    ) -> Bool {
        ownership.isAuthorized && !metadata.isOwner && metadata.isCloud
    }

    static func calculateShareSummary(from snapshot: RuuviTagCardSnapshot) -> String {
        calculateShareSummary(
            sharedTo: snapshot.ownership.sharedTo,
            maxShareCount: snapshot.ownership.maxShareCount
        )
    }

    static func calculateShareSummary(
        sharedTo: [String],
        maxShareCount: Int?
    ) -> String {
        if sharedTo.count > 0 {
            return RuuviLocalization
                .sharedToX(sharedTo.count, maxShareCount ?? 10)
        } else {
            return RuuviLocalization.TagSettings.NotShared.title
        }
    }

    func refreshMoreInfoRows() {
        moreInfoRows = Self.buildMoreInfoRows(from: snapshot)
    }

    // swiftlint:disable:next function_body_length
    static func buildMoreInfoRows(from snapshot: RuuviTagCardSnapshot) -> [MoreInfoRowModel] {
        var rows: [MoreInfoRowModel] = []
        let emptyValue = RuuviLocalization.na
        let display = snapshot.displayData

        let macValue = snapshot.identifierData.mac?.value ??
            snapshot.identifierData.luid?.value ??
            emptyValue
        rows.append(
            MoreInfoRowModel(
                id: "mac",
                title: RuuviLocalization.TagSettings.MacAddressTitleLabel.text,
                value: macValue,
                note: nil,
                noteColor: nil,
                action: .macAddress
            )
        )

        let dataFormat = formattedVersion(from: display.version)
        rows.append(
            MoreInfoRowModel(
                id: "dataFormat",
                title: RuuviLocalization.TagSettings.DataFormatTitleLabel.text,
                value: dataFormat,
                note: nil,
                noteColor: nil,
                action: .none
            )
        )

        let dataSource = formattedDataSource(from: display.source)
        rows.append(
            MoreInfoRowModel(
                id: "dataSource",
                title: RuuviLocalization.TagSettings.DataSourceTitleLabel.text,
                value: dataSource,
                note: nil,
                noteColor: nil,
                action: .none
            )
        )

        if snapshot.capabilities.showBatteryStatus {
            let (batteryValue, batteryNote, batteryColor) = formattedBatteryInfo(
                voltage: display.voltage,
                needsReplacement: display.batteryNeedsReplacement,
                firmwareVersion: display.version
            )
            rows.append(
                MoreInfoRowModel(
                    id: "battery",
                    title: RuuviLocalization.batteryVoltage,
                    value: batteryValue,
                    note: batteryNote,
                    noteColor: batteryColor,
                    action: .none
                )
            )
        }

        if let accX = display.accelerationX {
            rows.append(
                MoreInfoRowModel(
                    id: "accX",
                    title: RuuviLocalization.TagSettings.AccelerationXTitleLabel.text,
                    value: formattedAcceleration(from: accX),
                    note: nil,
                    noteColor: nil,
                    action: .none
                )
            )
        }

        if let accY = display.accelerationY {
            rows.append(
                MoreInfoRowModel(
                    id: "accY",
                    title: RuuviLocalization.TagSettings.AccelerationYTitleLabel.text,
                    value: formattedAcceleration(from: accY),
                    note: nil,
                    noteColor: nil,
                    action: .none
                )
            )
        }

        if let accZ = display.accelerationZ {
            rows.append(
                MoreInfoRowModel(
                    id: "accZ",
                    title: RuuviLocalization.TagSettings.AccelerationZTitleLabel.text,
                    value: formattedAcceleration(from: accZ),
                    note: nil,
                    noteColor: nil,
                    action: .none
                )
            )
        }

        if let txPower = display.txPower {
            rows.append(
                MoreInfoRowModel(
                    id: "txPower",
                    title: RuuviLocalization.TagSettings.TxPowerTitleLabel.text,
                    value: formattedTxPower(from: txPower),
                    note: nil,
                    noteColor: nil,
                    action: .txPower
                )
            )
        }

        let rssiValue = formattedRSSI(from: display.latestRSSI)
        rows.append(
            MoreInfoRowModel(
                id: "rssi",
                title: RuuviLocalization.signalStrengthWithUnit,
                value: rssiValue,
                note: nil,
                noteColor: nil,
                action: .none
            )
        )

        let measurementSequence = display.measurementSequenceNumber
            .map { "\($0)" } ?? emptyValue
        rows.append(
            MoreInfoRowModel(
                id: "msn",
                title: RuuviLocalization.TagSettings.MsnTitleLabel.text,
                value: measurementSequence,
                note: nil,
                noteColor: nil,
                action: .measurementSequence
            )
        )

        return rows
    }

    static func formattedVersion(from value: Int?) -> String {
        guard let value else { return RuuviLocalization.na }
        switch value {
        case 0xC5:
            return "C5"
        case 0xE1:
            return "E1"
        case 0x06:
            return "6"
        default:
            return "\(value)"
        }
    }

    static func formattedDataSource(from source: RuuviTagSensorRecordSource?) -> String {
        guard let source else { return RuuviLocalization.na }
        switch source {
        case .advertisement, .bgAdvertisement:
            return RuuviLocalization.TagSettings.DataSource.Advertisement.title
        case .heartbeat, .log:
            return RuuviLocalization.TagSettings.DataSource.Heartbeat.title
        case .ruuviNetwork:
            return RuuviLocalization.TagSettings.DataSource.Network.title
        default:
            return RuuviLocalization.na
        }
    }

    static func formattedBatteryInfo(
        voltage: Double?,
        needsReplacement: Bool,
        firmwareVersion: Int?
    ) -> (String, String?, Color?) {
        let value: String
        if let voltage {
            value = String.localizedStringWithFormat("%.3f", voltage) + " " + RuuviLocalization.v
        } else {
            value = RuuviLocalization.na
        }

        let firmware = RuuviDataFormat.dataFormat(from: firmwareVersion ?? 0)
        if firmware == .e1 || firmware == .v6 {
            return (value, nil, nil)
        }

        let status = needsReplacement
            ? "(\(RuuviLocalization.TagSettings.BatteryStatusLabel.Replace.message))"
            : "(\(RuuviLocalization.TagSettings.BatteryStatusLabel.Ok.message))"
        let color = needsReplacement
            ? Color(RuuviColor.orangeColor.color)
            : Color(RuuviColor.tintColor.color)
        return (value, status, color)
    }

    static func formattedAcceleration(from value: Double) -> String {
        String.localizedStringWithFormat("%.3f", value) + " " + RuuviLocalization.g
    }

    static func formattedTxPower(from value: Int) -> String {
        "\(value) \(RuuviLocalization.dBm)"
    }

    static func formattedRSSI(from value: Int?) -> String {
        guard let value else { return RuuviLocalization.na }
        return "\(value) \(RuuviLocalization.dBm)"
    }

    static func makeConnectionDisplayState(
        from connectionData: RuuviTagCardSnapshotConnectionData
    ) -> ConnectionDisplayState {
        let paired = RuuviLocalization.TagSettings.PairAndBackgroundScan.Paired.title
        let pairing = RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title
        let unpaired = RuuviLocalization.TagSettings.PairAndBackgroundScan.Unpaired.title

        if connectionData.isConnected {
            return ConnectionDisplayState(
                title: paired,
                isOn: true,
                isInProgress: false,
                isToggleEnabled: true
            )
        } else if connectionData.keepConnection {
            return ConnectionDisplayState(
                title: pairing,
                isOn: true,
                isInProgress: true,
                isToggleEnabled: true
            )
        } else {
            return ConnectionDisplayState(
                title: unpaired,
                isOn: false,
                isInProgress: false,
                isToggleEnabled: true
            )
        }
    }
}

extension CardsSettingsState {
    func setAlertSections(_ sections: [AlertSectionModel]) {
        let incomingIDs = Set(sections.map(\.id))
        expandedAlertSections = expandedAlertSections.intersection(incomingIDs)

        guard alertSections != sections else {
            return
        }

        alertSections = sections
    }

    func setKeepConnectionDisplay(
        title: String? = nil,
        isOn: Bool? = nil,
        isInProgress: Bool? = nil,
        isToggleEnabled: Bool? = nil
    ) {
        let state = ConnectionDisplayState(
            title: title ?? keepConnectionStatusText,
            isOn: isOn ?? isKeepConnectionOn,
            isInProgress: isInProgress ?? isKeepConnectionInProgress,
            isToggleEnabled: isToggleEnabled ?? isKeepConnectionToggleEnabled
        )
        updateConnectionDisplay(with: state)
    }

    func freezeKeepConnectionDisplay() {
        connectionDisplayFrozen = true
    }

    func unfreezeKeepConnectionDisplay() {
        connectionDisplayFrozen = false
        applyConnectionData(snapshot.connectionData)
    }

    fileprivate func applyConnectionData(_ connectionData: RuuviTagCardSnapshotConnectionData) {
        guard !connectionDisplayFrozen else { return }
        let state = CardsSettingsState.makeConnectionDisplayState(from: connectionData)
        updateConnectionDisplay(with: state)
    }

    fileprivate func updateConnectionDisplay(with state: ConnectionDisplayState) {
        keepConnectionStatusText = state.title
        isKeepConnectionOn = state.isOn
        isKeepConnectionInProgress = state.isInProgress
        isKeepConnectionToggleEnabled = state.isToggleEnabled
    }

    fileprivate func currentConnectionDisplayState() -> ConnectionDisplayState {
        ConnectionDisplayState(
            title: keepConnectionStatusText,
            isOn: isKeepConnectionOn,
            isInProgress: isKeepConnectionInProgress,
            isToggleEnabled: isKeepConnectionToggleEnabled
        )
    }

    struct MoreInfoRowModel: Identifiable {
        enum Action {
            case none
            case macAddress
            case txPower
            case measurementSequence
        }

        let id: String
        let title: String
        let value: String
        let note: String?
        let noteColor: Color?
        let action: Action

        var isTappable: Bool {
            action != .none
        }
    }

    struct AlertSectionModel: Identifiable, Equatable {
        struct HeaderState: Equatable {
            let isOn: Bool
            let mutedTill: Date?
            let alertState: AlertState?
            let showStatusLabel: Bool
        }

        let id: String
        let title: String
        let alertType: AlertType
        let headerState: HeaderState
        let configuration: AlertUIConfiguration
        let isInteractionEnabled: Bool
    }
}

struct MoreInfoView: View {
    @EnvironmentObject private var state: CardsSettingsState
    @EnvironmentObject private var actions: CardsSettingsActions

    var body: some View {
        VStack(spacing: 0) {
            if state.shouldShowNoValuesIndicator {
                Button(action: {
                    actions.didTapNoValuesIndicator.send()
                }) {
                    HStack {
                        Text(RuuviLocalization.TagSettings.Label.NoValues.text)
                            .font(.ruuviFootnote())
                            .foregroundColor(RuuviColor.textColor.swiftUIColor)
                        Spacer()
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                SettingsDivider()
            }

            SettingsDivider()

            ForEach(Array(state.moreInfoRows.enumerated()), id: \.element.id) { _, element in
                Group {
                    if element.isTappable {
                        Button {
                            handle(action: element.action)
                        } label: {
                            MoreInfoRow(row: element)
                        }
                        .buttonStyle(.plain)
                    } else {
                        MoreInfoRow(row: element)
                    }
                }
            }
        }
        .background(.clear)
    }

    private func handle(action: CardsSettingsState.MoreInfoRowModel.Action) {
        switch action {
        case .none:
            break
        case .macAddress:
            actions.didTapMoreInfoMacAddress.send()
        case .txPower:
            actions.didTapMoreInfoTxPower.send()
        case .measurementSequence:
            actions.didTapMoreInfoMeasurementSequence.send()
        }
    }
}
