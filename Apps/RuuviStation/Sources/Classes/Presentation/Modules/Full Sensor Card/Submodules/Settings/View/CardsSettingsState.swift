// swiftlint:disable file_length
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
    @Published private(set) var ledBrightnessSelection: RuuviLedBrightnessLevel = .defaultSelection
    @Published private(set) var showLedBrightnessRow: Bool = false
    @Published private(set) var backgroundImage: Image?
    @Published private(set) var moreInfoRows: [CardsSettingsMoreInfoRowModel]
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
    @Published private(set) var alertSections: [CardsSettingsAlertSectionModel] = []

    // MARK: - State management
    @Published var expandedSections: Set<String> = []
    @Published var expandedAlertSections: Set<String> = []
    @Published private(set) var lastExpandedSectionID: String?
    @Published private(set) var lastExpandedAlertID: String?

    // MARK: - Snapshot reference
    private(set) var snapshot: RuuviTagCardSnapshot
    private var cancellables = Set<AnyCancellable>()
    private var connectionDisplayFrozen = false

    private struct Constants {
        static let toggleDuration: TimeInterval = 0.25
    }

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
        moreInfoRows = CardsSettingsMoreInfoRowBuilder.buildMoreInfoRows(from: snapshot)
        firmwareVersion = snapshot.displayData.firmwareVersion.unwrapped
        applyConnectionData(snapshot.connectionData)
        showKeepConnectionStatusLabel = !snapshot.capabilities.hideSwitchStatusLabel
        temperatureOffset = snapshot.calibration.temperatureOffset.unwrapped
        humidityOffset = snapshot.calibration.humidityOffset.unwrapped
        pressureOffset = snapshot.calibration.pressureOffset.unwrapped
        showHumidityOffset = snapshot.calibration.isHumidityOffsetVisible
        showPressureOffset = snapshot.calibration.isPressureOffsetVisible
        hasLatestMeasurement = snapshot.latestRawRecord != nil
        showLedBrightnessRow = CardsSettingsState.shouldShowLedBrightness(
            for: snapshot
        )
    }

    // MARK: - Public Interface

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

    var ledBrightnessValue: String {
//        ledBrightnessSelection.title // TODO: Implement this when fw supports.
        ""
    }

    var shouldShowNoValuesIndicator: Bool {
        guard let version = snapshot.displayData.version else { return false }
        return version < 5
    }

    func updateVisibleMeasurementsSummary(
        value: String?,
        isVisible: Bool
    ) {
        visibleMeasurementsValue = value
        showVisibleMeasurementsRow = isVisible
    }

    func updateLedBrightnessSelection(_ selection: RuuviLedBrightnessLevel) {
        ledBrightnessSelection = selection
    }

    // MARK: - Settings Sections
    public var settingsSections: [CardsSettingsSection] {
        var sections: [CardsSettingsSection] = []

        // Offset Correction section - only show if user can edit it
        if showOffsetCorrection {
            sections.append(
                makeSection(
                    .offsetCorrection,
                    title: RuuviLocalization.offsetCorrection,
                    content: { AnyView(CardsSettingsOffsetCorrectionSectionView()) }
                )
            )
        }

        // More Info section
        sections.append(
            makeSection(
                .moreInfo,
                title: RuuviLocalization.moreInfo,
                content: { AnyView(CardsSettingsMoreInfoSectionView()) }
            )
        )

        // Firmware Update section
        sections.append(
            makeSection(
                .firmwareUpdate,
                title: RuuviLocalization.firmware,
                content: { AnyView(CardsSettingsFirmwareSectionView()) }
            )
        )

        // Remove section
        sections.append(
            makeSection(
                .remove,
                title: RuuviLocalization.remove,
                content: { AnyView(CardsSettingsRemoveSectionView()) }
            )
        )

        return sections
    }

    // MARK: - Actions
    func toggleSection(_ id: String) {
        withAnimation(.easeInOut(duration: Constants.toggleDuration)) {
            if expandedSections.contains(id) {
                expandedSections.remove(id)
                lastExpandedSectionID = nil
            } else {
                expandedSections.insert(id)
                lastExpandedSectionID = id
            }
        }
    }

    func toggleSection(_ id: CardsSettingsSectionID) {
        toggleSection(id.rawValue)
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

    func setAlertSections(_ sections: [CardsSettingsAlertSectionModel]) {
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
        let state = CardsSettingsBTConnectionDisplayState(
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
}

// MARK: - Binding
private extension CardsSettingsState {
    private func bind(to snapshot: RuuviTagCardSnapshot) {
        bindDisplayData(snapshot)
        bindOwnership(snapshot)
        bindShareVisibility(snapshot)
        bindMoreInfoRefresh(for: snapshot)
        bindConnection(snapshot)
        bindCalibration(snapshot)
        bindLatestMeasurement(snapshot)
    }

    private func bindDisplayData(_ snapshot: RuuviTagCardSnapshot) {
        snapshot.$displayData
            .map(\.name)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$name)

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
    }

    private func bindOwnership(_ snapshot: RuuviTagCardSnapshot) {
        snapshot.$ownership
            .map { $0.ownerName.unwrapped }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$ownerName)

        snapshot.$ownership
            .map(\.isAuthorized)
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$showOwner)

        snapshot.$ownership
            .map { $0.ownersPlan.unwrapped }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$ownersPlan)

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
    }

    private func bindShareVisibility(_ snapshot: RuuviTagCardSnapshot) {
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
    }

    private func bindMoreInfoRefresh(for snapshot: RuuviTagCardSnapshot) {
        let displayPublisher = snapshot.$displayData.map { _ in }
        let capabilitiesPublisher = snapshot.$capabilities.map { _ in }
        let metadataPublisher = snapshot.$metadata.map { _ in }

        Publishers.Merge3(displayPublisher, capabilitiesPublisher, metadataPublisher)
            .sink { [weak self] _ in
                self?.refreshMoreInfoRows()
            }
            .store(in: &cancellables)
    }

    private func bindConnection(_ snapshot: RuuviTagCardSnapshot) {
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
    }

    private func bindCalibration(_ snapshot: RuuviTagCardSnapshot) {
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
    }

    private func bindLatestMeasurement(_ snapshot: RuuviTagCardSnapshot) {
        snapshot.$latestRawRecord
            .map { $0 != nil }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasLatestMeasurement)
    }
}

// MARK: Private helpers
private extension CardsSettingsState {
    private func makeSection(
        _ id: CardsSettingsSectionID,
        title: String,
        content: @escaping () -> AnyView
    ) -> CardsSettingsSection {
        CardsSettingsSection(id: id.rawValue, title: title, content: content)
    }

    // MARK: - Ownership
    static func shouldShowOwnersPlan(
        ownership: RuuviTagCardSnapshotOwnership,
        metadata: RuuviTagCardSnapshotMetadata
    ) -> Bool {
        ownership.isAuthorized && !metadata.isOwner && metadata.isCloud
    }

    static func shouldShowLedBrightness(
        for snapshot: RuuviTagCardSnapshot
    ) -> Bool {
        let format = RuuviDataFormat.dataFormat(
            from: snapshot.displayData.version.bound
        )
        let ruuviDeviceType: RuuviDeviceType =
            format == .e1 || format == .v6 ? .ruuviAir : .ruuviTag
        return ruuviDeviceType == .ruuviAir
    }

    static func calculateShareSummary(
        from snapshot: RuuviTagCardSnapshot
    ) -> String {
        calculateShareSummary(
            sharedTo: snapshot.ownership.sharedTo,
            maxShareCount: snapshot.ownership.maxShareCount
        )
    }

    static func calculateShareSummary(
        sharedTo: [String],
        maxShareCount: Int?
    ) -> String {
        guard !sharedTo.isEmpty else {
            return RuuviLocalization.TagSettings.NotShared.title
        }
        return RuuviLocalization.sharedToX(sharedTo.count, maxShareCount ?? 10)
    }

    // MARK: - More Info Rows
    func refreshMoreInfoRows() {
        moreInfoRows = CardsSettingsMoreInfoRowBuilder.buildMoreInfoRows(from: snapshot)
    }

    // MARK: - Connection Display
    static func makeConnectionDisplayState(
        from connectionData: RuuviTagCardSnapshotConnectionData
    ) -> CardsSettingsBTConnectionDisplayState {
        let paired = RuuviLocalization.TagSettings.PairAndBackgroundScan.Paired.title
        let pairing = RuuviLocalization.TagSettings.PairAndBackgroundScan.Pairing.title
        let unpaired = RuuviLocalization.TagSettings.PairAndBackgroundScan.Unpaired.title

        if connectionData.isConnected {
            return CardsSettingsBTConnectionDisplayState(
                title: paired,
                isOn: true,
                isInProgress: false,
                isToggleEnabled: true
            )
        } else if connectionData.keepConnection {
            return CardsSettingsBTConnectionDisplayState(
                title: pairing,
                isOn: true,
                isInProgress: true,
                isToggleEnabled: true
            )
        } else {
            return CardsSettingsBTConnectionDisplayState(
                title: unpaired,
                isOn: false,
                isInProgress: false,
                isToggleEnabled: true
            )
        }
    }
}

extension CardsSettingsState {
    fileprivate func applyConnectionData(
        _ connectionData: RuuviTagCardSnapshotConnectionData
    ) {
        guard !connectionDisplayFrozen else { return }
        let state = CardsSettingsState.makeConnectionDisplayState(from: connectionData)
        updateConnectionDisplay(with: state)
    }

    fileprivate func updateConnectionDisplay(
        with state: CardsSettingsBTConnectionDisplayState
    ) {
        keepConnectionStatusText = state.title
        isKeepConnectionOn = state.isOn
        isKeepConnectionInProgress = state.isInProgress
        isKeepConnectionToggleEnabled = state.isToggleEnabled
    }

    fileprivate func currentConnectionDisplayState() -> CardsSettingsBTConnectionDisplayState {
        CardsSettingsBTConnectionDisplayState(
            title: keepConnectionStatusText,
            isOn: isKeepConnectionOn,
            isInProgress: isKeepConnectionInProgress,
            isToggleEnabled: isKeepConnectionToggleEnabled
        )
    }
}

// swiftlint:enable file_length
