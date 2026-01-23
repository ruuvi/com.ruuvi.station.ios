// swiftlint:disable file_length

import Foundation
import Combine
import RuuviLocalization
import RuuviOntology
import RuuviLocal
import RuuviService

final class VisibilitySettingsPresenter: VisibilitySettingsModuleInput {
    private struct PersistSignature: Equatable {
        let usesDefaultOrder: Bool
        let displayOrderCodes: [String]?
    }

    weak var view: VisibilitySettingsViewInput?
    var router: VisibilitySettingsRouterInput?
    weak var output: VisibilitySettingsModuleOutput?

    private let sensorPropertiesService: RuuviServiceSensorProperties
    private let settings: RuuviLocalSettings
    private var snapshotCancellables = Set<AnyCancellable>()

    private var snapshot: RuuviTagCardSnapshot?
    private var sensor: RuuviTagSensor?
    private var sensorSettings: SensorSettings?

    private var availableVariants: [MeasurementDisplayVariant] = []
    private var visibleVariants: [MeasurementDisplayVariant] = []
    private var hiddenVariants: [MeasurementDisplayVariant] = []
    private var usesDefaultOrder: Bool = true
    private var lastKnownCustomOrderCodes: [String]?
    private var isSaving: Bool = false
    private var hasPendingPersistRequest = false
    private var needsPersistVisibleReorder: Bool = false
    private let persistDebouncer = Debouncer(delay: 1.0)
    private var isPersistScheduled = false
    private var hasUnsavedChanges = false
    private var inFlightPersistSignature: PersistSignature?

    init(
        sensorPropertiesService: RuuviServiceSensorProperties,
        settings: RuuviLocalSettings
    ) {
        self.sensorPropertiesService = sensorPropertiesService
        self.settings = settings
    }

    func configure(
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        sensorSettings: SensorSettings?
    ) {
        self.snapshot = snapshot
        self.sensor = sensor
        self.sensorSettings = sensorSettings
        self.lastKnownCustomOrderCodes = sensorSettings?.displayOrder
    }

    func configure(output: VisibilitySettingsModuleOutput?) {
        self.output = output
    }

    func dismiss(completion: (() -> Void)?) {
        shutdown()
        completion?()
    }
}

extension VisibilitySettingsPresenter: VisibilitySettingsViewOutput {
    func viewDidLoad() {
        guard let snapshot, snapshot.metadata.isOwner else {
            closeModule()
            return
        }
        rebuildState()
        presentCurrentState()
        observeSnapshotChanges()
    }

    func viewDidAskToDismiss() {
        flushPendingPersistIfNeeded()
        closeModule()
    }

    func viewDidToggleUseDefault(isOn: Bool) {
        guard isOn != usesDefaultOrder else { return }

        if isOn {
            handleUseDefaultToggleOn()
        } else {
            usesDefaultOrder = false
            if let codes = lastKnownCustomOrderCodes, !codes.isEmpty {
                let variants = codes.compactMap { code in
                    RuuviTagDataService.measurementVariant(for: code)
                }
                if !variants.isEmpty {
                    visibleVariants = resolveVisible(
                        from: variants,
                        available: availableVariants
                    )
                    hiddenVariants = resolveHidden(
                        from: [],
                        available: availableVariants,
                        visible: visibleVariants
                    )
                }
            }
            schedulePersist()
            presentCurrentState()
        }
    }

    func viewDidRequestHideItem(at index: Int) {
        guard visibleVariants.indices.contains(index) else { return }
        guard visibleVariants.count > 1 else {
            view?.showMessage(RuuviLocalization.visibleMeasurementsLastElementMessage)
            return
        }

        let variant = visibleVariants[index]
        if shouldWarnAboutActiveAlertWhenHiding(variant: variant, excludingIndex: index) {
            let measurementName = variant.type.shortNameWithUnit(for: variant)
            let message = RuuviLocalization.visibleMeasurementsActiveAlertConfirmation(measurementName)
            view?.presentConfirmation(
                title: RuuviLocalization.confirm,
                message: message,
                confirmTitle: RuuviLocalization.yes,
                cancelTitle: RuuviLocalization.no,
                onConfirm: { [weak self] in
                    self?.performHide(at: index)
                },
                onCancel: { [weak self] in
                    self?.presentCurrentState()
                }
            )
            return
        }

        performHide(at: index)
    }

    func viewDidRequestShowItem(at index: Int) {
        guard hiddenVariants.indices.contains(index) else { return }
        let variant = hiddenVariants.remove(at: index)
        guard !visibleVariants.contains(variant) else {
            presentCurrentState()
            return
        }
        visibleVariants.append(variant)
        usesDefaultOrder = false
        schedulePersist()
        presentCurrentState()
    }

    func viewDidStartReorderingVisibleItems() {
        // TODO: Implement
    }

    func viewDidMoveVisibleItem(from sourceIndex: Int, to destinationIndex: Int) {
        guard visibleVariants.indices.contains(sourceIndex),
              visibleVariants.indices.contains(destinationIndex),
              sourceIndex != destinationIndex else {
            presentCurrentState()
            return
        }

        let variant = visibleVariants.remove(at: sourceIndex)
        visibleVariants.insert(variant, at: destinationIndex)
        usesDefaultOrder = false
        needsPersistVisibleReorder = true
        presentCurrentState()
    }

    func viewDidFinishReorderingVisibleItems() {
        guard needsPersistVisibleReorder else { return }
        needsPersistVisibleReorder = false
        schedulePersist()
    }

    func viewWillDisappear() {
        flushPendingPersistIfNeeded()
    }
}

// MARK: - Private helpers
private extension VisibilitySettingsPresenter {
    enum HiddenMeasurementsOrder {
        static let variants: [MeasurementDisplayVariant] = [
            MeasurementDisplayVariant(type: .aqi),
            MeasurementDisplayVariant(type: .co2),
            MeasurementDisplayVariant(type: .pm10),
            MeasurementDisplayVariant(type: .pm25),
            MeasurementDisplayVariant(type: .pm40),
            MeasurementDisplayVariant(type: .pm100),
            MeasurementDisplayVariant(type: .voc),
            MeasurementDisplayVariant(type: .nox),
            MeasurementDisplayVariant(type: .temperature, temperatureUnit: .celsius),
            MeasurementDisplayVariant(type: .temperature, temperatureUnit: .fahrenheit),
            MeasurementDisplayVariant(type: .temperature, temperatureUnit: .kelvin),
            MeasurementDisplayVariant(type: .humidity, humidityUnit: .percent),
            MeasurementDisplayVariant(type: .humidity, humidityUnit: .gm3),
            MeasurementDisplayVariant(
                type: .humidity,
                temperatureUnit: .celsius,
                humidityUnit: .dew
            ),
            MeasurementDisplayVariant(
                type: .humidity,
                temperatureUnit: .fahrenheit,
                humidityUnit: .dew
            ),
            MeasurementDisplayVariant(
                type: .humidity,
                temperatureUnit: .kelvin,
                humidityUnit: .dew
            ),
            MeasurementDisplayVariant(type: .pressure, pressureUnit: .hectopascals),
            MeasurementDisplayVariant(type: .pressure, pressureUnit: .newtonsPerMetersSquared),
            MeasurementDisplayVariant(type: .pressure, pressureUnit: .millimetersOfMercury),
            MeasurementDisplayVariant(type: .pressure, pressureUnit: .inchesOfMercury),
            MeasurementDisplayVariant(type: .movementCounter),
            MeasurementDisplayVariant(type: .soundInstant),
            MeasurementDisplayVariant(type: .soundAverage),
            MeasurementDisplayVariant(type: .soundPeak),
            MeasurementDisplayVariant(type: .luminosity),
            MeasurementDisplayVariant(type: .voltage),
            MeasurementDisplayVariant(type: .accelerationX),
            MeasurementDisplayVariant(type: .accelerationY),
            MeasurementDisplayVariant(type: .accelerationZ),
            MeasurementDisplayVariant(type: .rssi),
            MeasurementDisplayVariant(type: .measurementSequenceNumber),
        ]

        static let index: [MeasurementDisplayVariant: Int] = {
            Dictionary(
                uniqueKeysWithValues: variants.enumerated().map { ($0.element, $0.offset) }
            )
        }()
    }

    func closeModule() {
        output?.visibilitySettingsModuleDidFinish(self)
        dismiss { [weak self] in
            self?.router?.dismiss()
        }
    }

    func shutdown() {
        persistDebouncer.cancel()
        isPersistScheduled = false
        hasUnsavedChanges = false
        inFlightPersistSignature = nil
        snapshotCancellables.removeAll()
        availableVariants.removeAll()
        visibleVariants.removeAll()
        hiddenVariants.removeAll()
        lastKnownCustomOrderCodes = nil
        usesDefaultOrder = true
        isSaving = false
        hasPendingPersistRequest = false
        needsPersistVisibleReorder = false
        snapshot = nil
        sensor = nil
        sensorSettings = nil
    }

    func observeSnapshotChanges() {
        snapshotCancellables.removeAll()
        guard let snapshot else { return }

        snapshot.$displayData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildState()
                self?.presentPreviewUpdate()
            }
            .store(in: &snapshotCancellables)

        snapshot.$alertData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildState()
                self?.presentPreviewUpdate()
            }
            .store(in: &snapshotCancellables)

        snapshot.$metadata
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.rebuildState()
                self?.presentPreviewUpdate()
            }
            .store(in: &snapshotCancellables)
    }

    func presentPreviewUpdate() {
        presentCurrentState()
    }

    func rebuildState() {
        guard let snapshot else { return }
        let currentVisibility = snapshot.displayData.measurementVisibility

        if let explicit = currentVisibility?.usesDefaultOrder {
            usesDefaultOrder = explicit
        } else if let sensorDefault = sensorSettings?.defaultDisplayOrder {
            usesDefaultOrder = sensorDefault
        } else if let codes = sensorSettings?.displayOrder, !codes.isEmpty {
            usesDefaultOrder = false
        } else {
            usesDefaultOrder = true
        }

        let available = currentVisibility?.availableVariants
            ?? defaultAvailableVariants(for: snapshot)
        availableVariants = available

        let baseVisible: [MeasurementDisplayVariant]
        if usesDefaultOrder {
            baseVisible = defaultVisibleVariants(for: snapshot)
        } else {
            baseVisible = currentVisibility?.visibleVariants ?? defaultVisibleVariants(for: snapshot)
        }

        visibleVariants = resolveVisible(from: baseVisible, available: available)
        applyForcedVisibilityIfNeeded()
        if visibleVariants.isEmpty {
            visibleVariants = available
            applyForcedVisibilityIfNeeded()
        }

        let baseHidden = currentVisibility?.hiddenVariants ?? []
        hiddenVariants = resolveHidden(
            from: baseHidden,
            available: available,
            visible: visibleVariants
        )
        if !usesDefaultOrder {
            lastKnownCustomOrderCodes = visibleVariants.compactMap {
                RuuviTagDataService.measurementCode(for: $0)
            }
        } else if lastKnownCustomOrderCodes == nil {
            lastKnownCustomOrderCodes = sensorSettings?.displayOrder
        }
    }

    func defaultAvailableVariants(for snapshot: RuuviTagCardSnapshot) -> [MeasurementDisplayVariant] {
        let profile = RuuviTagDataService.measurementDisplayProfile(for: snapshot)
        return profile.entriesSupporting(.indicator).map(\.variant)
    }

    func defaultVisibleVariants(for snapshot: RuuviTagCardSnapshot) -> [MeasurementDisplayVariant] {
        RuuviTagDataService.measurementDisplayProfile(for: snapshot)
            .orderedVisibleVariants(for: .indicator)
    }

    func defaultVisibleVariants(for sensor: RuuviTagSensor) -> [MeasurementDisplayVariant] {
        RuuviTagDataService.defaultMeasurementDisplayProfile(for: sensor)
            .orderedVisibleVariants(for: .indicator)
    }

    func resolveVisible(
        from initial: [MeasurementDisplayVariant],
        available: [MeasurementDisplayVariant]
    ) -> [MeasurementDisplayVariant] {
        var filtered: [MeasurementDisplayVariant] = []
        for variant in initial where available.contains(variant) {
            filtered.append(variant)
        }
        if filtered.isEmpty {
            filtered = available
        }
        return filtered
    }

    func resolveHidden(
        from initial: [MeasurementDisplayVariant],
        available: [MeasurementDisplayVariant],
        visible: [MeasurementDisplayVariant]
    ) -> [MeasurementDisplayVariant] {
        var hidden: [MeasurementDisplayVariant] = []
        for variant in initial where available.contains(variant) && !visible.contains(variant) {
            hidden.append(variant)
        }

        let remainder = available.filter {
            !visible.contains($0) && !hidden.contains($0)
        }
        hidden.append(contentsOf: remainder)
        return orderedHiddenVariants(hidden)
    }

    func presentCurrentState() {
        guard let view else { return }

        let visibleItems = visibleVariants.map { makeItemViewModel(for: $0) }
        let hiddenItems = hiddenVariants.map { makeItemViewModel(for: $0) }
        let preview = makePreviewViewModel()

        let viewModel = VisibilitySettingsViewModel(
            descriptionText: RuuviLocalization.visibleMeasurementsDescription,
            useDefault: usesDefaultOrder,
            visibleItems: visibleItems,
            hiddenItems: hiddenItems,
            preview: preview
        )

        view.display(viewModel: viewModel)
    }

    func makeItemViewModel(
        for variant: MeasurementDisplayVariant
    ) -> VisibilitySettingsItemViewModel {
        VisibilitySettingsItemViewModel(
            variant: variant,
            title: variant.type.shortNameWithUnit(for: variant)
        )
    }

    func makePreviewViewModel() -> VisibilitySettingsPreviewViewModel? {
        guard let snapshot else { return nil }

        let previewGrid = makePreviewIndicatorGrid(for: snapshot)
        var displayData = snapshot.displayData
        displayData.indicatorGrid = previewGrid
        displayData.hasNoData = previewGrid == nil

        let previewSnapshot = RuuviTagCardSnapshot(
            id: "\(snapshot.id)-visibility-preview",
            identifierData: snapshot.identifierData,
            displayData: displayData,
            metadata: snapshot.metadata,
            alertData: snapshot.alertData,
            connectionData: snapshot.connectionData,
            ownership: snapshot.ownership,
            calibration: snapshot.calibration,
            capabilities: snapshot.capabilities,
            lastUpdated: snapshot.lastUpdated
        )

        return VisibilitySettingsPreviewViewModel(
            snapshot: previewSnapshot,
            dashboardType: settings.dashboardType
        )
    }

    func makePreviewIndicatorGrid(
        for snapshot: RuuviTagCardSnapshot
    ) -> RuuviTagCardSnapshotIndicatorGridConfiguration? {
        guard !visibleVariants.isEmpty else {
            return snapshot.displayData.indicatorGrid
        }

        let existingIndicators = snapshot.displayData.indicatorGrid?.indicators ?? []
        let indicatorLookup = Dictionary(uniqueKeysWithValues: existingIndicators.map {
            ($0.variant, $0)
        })

        let previewIndicators: [RuuviTagCardSnapshotIndicatorData] = visibleVariants.compactMap { variant in
            indicatorData(for: variant, existing: indicatorLookup)
        }

        guard let grid = IndicatorDataManager.createGridConfiguration(
            indicators: previewIndicators,
            orderedVariants: visibleVariants
        ) else {
            return nil
        }

        return grid
    }

    func indicatorData(
        for variant: MeasurementDisplayVariant,
        existing: [MeasurementDisplayVariant: RuuviTagCardSnapshotIndicatorData]
    ) -> RuuviTagCardSnapshotIndicatorData? {
        existing[variant]
    }

    // swiftlint:disable:next function_body_length
    func handleUseDefaultToggleOn() {
        guard let sensor else {
            usesDefaultOrder = true
            presentCurrentState()
            return
        }
        lastKnownCustomOrderCodes = visibleVariants.compactMap {
            RuuviTagDataService.measurementCode(for: $0)
        }
        let defaultVisible: [MeasurementDisplayVariant]
        if let snapshot {
            defaultVisible = defaultVisibleVariants(for: snapshot)
        } else {
            defaultVisible = defaultVisibleVariants(for: sensor)
        }
        let typeNamesNeedingConfirmation = measurementTypeNamesWithActiveAlertsWhenSwitchingToDefault(
            targetVisible: defaultVisible
        )

        let applyDefault: () -> Void = { [weak self] in
            guard let self else { return }
            self.visibleVariants = self.resolveVisible(
                from: defaultVisible,
                available: self.availableVariants
            )
            self.hiddenVariants = self.resolveHidden(
                from: [],
                available: self.availableVariants,
                visible: self.visibleVariants
            )
            self.usesDefaultOrder = true
            self.schedulePersist()
            self.presentCurrentState()
        }

        guard !typeNamesNeedingConfirmation.isEmpty else {
            applyDefault()
            return
        }

        let names = typeNamesNeedingConfirmation.joined(separator: ", ")
        let message: String
        if typeNamesNeedingConfirmation.count == 1 {
            message = RuuviLocalization.visibleMeasurementsChangeUseDefaultConfirmation(names)
        } else {
            message = RuuviLocalization.visibleMeasurementsChangeUseDefaultMultipleAlertsConfirmation(names)
        }
        view?.presentConfirmation(
            title: RuuviLocalization.visibleMeasurements,
            message: message,
            confirmTitle: RuuviLocalization.confirm,
            cancelTitle: RuuviLocalization.cancel,
            onConfirm: applyDefault,
            onCancel: { [weak self] in
                guard let self else { return }
                self.view?.setUseDefaultSwitch(isOn: false)
                self.usesDefaultOrder = false
                self.presentCurrentState()
            }
        )
    }

    func measurementTypeNamesWithActiveAlertsWhenSwitchingToDefault(
        targetVisible: [MeasurementDisplayVariant]
    ) -> [String] {
        let targetTypes = targetVisible.map(\.type)
        var affectedTypes: [MeasurementType] = []
        for variant in visibleVariants {
            let type = variant.type
            guard !targetTypes.contains(where: { $0.isSameCase(as: type) }) else {
                continue
            }
            if hasActiveAlert(for: type) {
                affectedTypes.append(type)
            }
        }

        let uniqueTypes = affectedTypes.reduce(into: [MeasurementType]()) { partial, type in
            if !partial.contains(where: { $0.isSameCase(as: type) }) {
                partial.append(type)
            }
        }
        return uniqueTypes.map { $0.shortName }
    }

    func performHide(at index: Int) {
        let variant = visibleVariants.remove(at: index)
        disableAlertIfNeeded(for: variant)
        if !hiddenVariants.contains(variant) {
            hiddenVariants.append(variant)
            hiddenVariants = orderedHiddenVariants(hiddenVariants)
        }
        usesDefaultOrder = false
        schedulePersist()
        presentCurrentState()
    }

    func shouldWarnAboutActiveAlertWhenHiding(
        variant: MeasurementDisplayVariant,
        excludingIndex: Int
    ) -> Bool {
        guard hasActiveAlert(for: variant.type) else { return false }
        let remainingVisibleCount = visibleVariants.enumerated().filter { entry in
            entry.offset != excludingIndex && entry.element.type.isSameCase(as: variant.type)
        }.count
        return remainingVisibleCount == 0
    }

    func hasActiveAlert(for type: MeasurementType) -> Bool {
        guard let snapshot else { return false }
        let hasMeasurementAlert = snapshot.alertData.alertConfigurations.values.contains { config in
            guard let alertType = config.alertType ?? config.type?.toAlertType() else { return false }
            guard let measurementType = alertType.toMeasurementType() else { return false }
            return measurementType.isSameCase(as: type) && config.isActive
        }

        if hasMeasurementAlert {
            return true
        }

        return snapshot.alertData.nonMeasurementAlerts.contains { alertType, config in
            guard let measurementType = alertType.toMeasurementType() else { return false }
            return measurementType.isSameCase(as: type) && config.isActive
        }
    }

    func forcedVisibleMeasurementTypes(for snapshot: RuuviTagCardSnapshot) -> [MeasurementType] {
        var forced: [MeasurementType] = []
        if snapshot.getAlertConfig(for: .rssi)?.isActive == true {
            forced.append(.rssi)
        }
        return forced
    }

    func persistCurrentSelection() {
        guard let sensor else { return }

        if isSaving {
            hasPendingPersistRequest = true
            return
        }

        let displayOrderCodes = currentDisplayOrderCodes()
        inFlightPersistSignature = PersistSignature(
            usesDefaultOrder: usesDefaultOrder,
            displayOrderCodes: displayOrderCodes
        )

        isSaving = true
        view?.setSaving(true)

        sensorPropertiesService
            .updateDisplaySettings(
                for: sensor,
                displayOrder: displayOrderCodes,
                defaultDisplayOrder: usesDefaultOrder
            )
            .on(success: { [weak self] settings in
                self?.handlePersistSuccess(
                    settings: settings,
                    displayOrderCodes: displayOrderCodes
                )
            }, failure: { [weak self] error in
                self?.handlePersistFailure(error: error)
            })
    }

    private func applySelectionToSnapshot() {
        guard let snapshot else { return }
        let visibility = RuuviTagCardSnapshotMeasurementVisibility(
            usesDefaultOrder: usesDefaultOrder,
            availableVariants: availableVariants,
            visibleVariants: visibleVariants,
            hiddenVariants: hiddenVariants
        )

        snapshot.updateMeasurementVisibility(visibility)

        let newGrid = makePreviewIndicatorGrid(for: snapshot)
        var updatedDisplayData = snapshot.displayData
        if updatedDisplayData.indicatorGrid != newGrid || updatedDisplayData.hasNoData != (newGrid == nil) {
            updatedDisplayData.indicatorGrid = newGrid
            updatedDisplayData.hasNoData = newGrid == nil
            snapshot.displayData = updatedDisplayData
        }
    }

    func updateMeasurementPreferenceCache(with codes: [String]?) {
        guard let sensor else { return }
        if usesDefaultOrder {
            RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
        } else if let codes, !codes.isEmpty {
            let preference = RuuviTagDataService.MeasurementDisplayPreference(
                defaultDisplayOrder: false,
                displayOrderCodes: codes
            )
            RuuviTagDataService.setMeasurementDisplayPreference(
                preference,
                for: sensor.id
            )
        } else {
            RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
        }
    }

    func disableAlertIfNeeded(for variant: MeasurementDisplayVariant) {
        guard let snapshot else { return }
        guard let alertType = variant.toAlertType() else { return }
        guard snapshot.getAlertConfig(for: alertType)?.isActive == true else { return }
        let hasOtherVisibleVariants = visibleVariants.contains {
            $0.type.isSameCase(as: variant.type) && $0 != variant
        }
        guard !hasOtherVisibleVariants else { return }
        withAlertService { service, snapshot, sensor in
            service.setAlertState(
                for: alertType,
                isOn: false,
                snapshot: snapshot,
                physicalSensor: sensor
            )
        }
    }

    func applyForcedVisibilityIfNeeded() {
        guard let snapshot else { return }
        let forcedTypes = forcedVisibleMeasurementTypes(for: snapshot)
        guard !forcedTypes.isEmpty else { return }

        for type in forcedTypes {
            guard let variant = availableVariants.first(where: { $0.type.isSameCase(as: type) }) else {
                continue
            }
            ensureVariantVisible(variant)
        }
    }

    func ensureVariantVisible(_ variant: MeasurementDisplayVariant) {
        guard !visibleVariants.contains(variant) else { return }
        guard let targetIndex = availableVariants.firstIndex(of: variant) else {
            visibleVariants.append(variant)
            return
        }

        var inserted = false
        for (index, entry) in visibleVariants.enumerated() {
            guard let entryIndex = availableVariants.firstIndex(of: entry) else { continue }
            if entryIndex > targetIndex {
                visibleVariants.insert(variant, at: index)
                inserted = true
                break
            }
        }

        if !inserted {
            visibleVariants.append(variant)
        }
    }

    func orderedHiddenVariants(
        _ variants: [MeasurementDisplayVariant]
    ) -> [MeasurementDisplayVariant] {
        guard variants.count > 1 else { return variants }
        let orderIndex = HiddenMeasurementsOrder.index
        return variants.enumerated().sorted { lhs, rhs in
            let lhsRank = orderIndex[normalizedHiddenVariant(lhs.element)] ?? Int.max
            let rhsRank = orderIndex[normalizedHiddenVariant(rhs.element)] ?? Int.max
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    func normalizedHiddenVariant(
        _ variant: MeasurementDisplayVariant
    ) -> MeasurementDisplayVariant {
        switch variant.type {
        case .temperature:
            let unit = variant.temperatureUnit ?? .celsius
            return MeasurementDisplayVariant(type: .temperature, temperatureUnit: unit)
        case .humidity:
            let unit = variant.humidityUnit ?? .percent
            if unit == .dew {
                let temperatureUnit = variant.temperatureUnit ?? .celsius
                return MeasurementDisplayVariant(
                    type: .humidity,
                    temperatureUnit: temperatureUnit,
                    humidityUnit: .dew
                )
            }
            return MeasurementDisplayVariant(type: .humidity, humidityUnit: unit)
        case .pressure:
            let unit = variant.pressureUnit ?? .hectopascals
            return MeasurementDisplayVariant(type: .pressure, pressureUnit: unit)
        default:
            return MeasurementDisplayVariant(type: variant.type)
        }
    }

    func withAlertService(
        _ block: (RuuviTagAlertService, RuuviTagCardSnapshot, RuuviTagSensor) -> Void
    ) {
        guard let snapshot, let sensor else { return }
        RuuviTagServiceCoordinatorManager.shared.withCoordinator { coordinator in
            block(coordinator.services.alert, snapshot, sensor)
        }
    }

    func handlePersistSuccess(
        settings: SensorSettings,
        displayOrderCodes: [String]?
    ) {
        runOnMain { [weak self] in
            guard let self else { return }
            self.sensorSettings = settings
            if let codes = settings.displayOrder, !codes.isEmpty {
                self.lastKnownCustomOrderCodes = codes
            }
            self.updateMeasurementPreferenceCache(with: displayOrderCodes)
            self.applySelectionToSnapshot()
            if !self.hasPendingPersistRequest && !self.isPersistScheduled {
                self.hasUnsavedChanges = false
            }
            self.inFlightPersistSignature = nil
            self.finishPersist()
        }
    }

    func handlePersistFailure(error: Error) {
        runOnMain { [weak self] in
            guard let self else { return }
            self.view?.showMessage(error.localizedDescription)
            if !self.hasPendingPersistRequest && !self.isPersistScheduled {
                self.hasUnsavedChanges = false
            }
            self.inFlightPersistSignature = nil
            self.finishPersist()
            self.rebuildState()
            self.presentCurrentState()
        }
    }

    func finishPersist() {
        isSaving = false
        view?.setSaving(false)
        if hasPendingPersistRequest {
            hasPendingPersistRequest = false
            persistCurrentSelection()
        }
    }

    func schedulePersist() {
        let displayOrderCodes = currentDisplayOrderCodes()
        updateMeasurementPreferenceCache(with: displayOrderCodes)
        applySelectionToSnapshot()
        hasUnsavedChanges = true
        isPersistScheduled = true
        persistDebouncer.run { [weak self] in
            guard let self else { return }
            self.isPersistScheduled = false
            self.persistCurrentSelection()
        }
    }

    func flushPendingPersistIfNeeded() {
        guard hasUnsavedChanges || isPersistScheduled || isSaving || hasPendingPersistRequest else {
            return
        }
        persistDebouncer.cancel()
        isPersistScheduled = false
        let currentSignature = PersistSignature(
            usesDefaultOrder: usesDefaultOrder,
            displayOrderCodes: currentDisplayOrderCodes()
        )
        if isSaving {
            if let inFlightPersistSignature, inFlightPersistSignature == currentSignature {
                return
            }
            hasPendingPersistRequest = true
            return
        }
        persistCurrentSelection()
    }

    func currentDisplayOrderCodes() -> [String]? {
        guard !usesDefaultOrder else { return nil }
        let codes = visibleVariants.compactMap { variant in
            RuuviTagDataService.measurementCode(for: variant)
        }
        if !codes.isEmpty {
            lastKnownCustomOrderCodes = codes
        }
        return codes.isEmpty ? nil : codes
    }

    func runOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}

// swiftlint:enable file_length
