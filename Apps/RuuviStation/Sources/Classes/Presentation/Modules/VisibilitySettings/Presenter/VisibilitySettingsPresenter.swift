import Foundation
import Combine
import Future
import RuuviLocalization
import RuuviOntology
import RuuviLocal
import RuuviService

final class VisibilitySettingsPresenter: VisibilitySettingsModuleInput {
    weak var view: VisibilitySettingsViewInput?
    var router: VisibilitySettingsRouterInput?

    private let flags: RuuviLocalFlags
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
    private var cachedCustomVisibleVariants: [MeasurementDisplayVariant]?
    private var isSaving: Bool = false
    private var needsPersistVisibleReorder: Bool = false

    init(
        flags: RuuviLocalFlags,
        sensorPropertiesService: RuuviServiceSensorProperties,
        settings: RuuviLocalSettings
    ) {
        self.flags = flags
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
    }
}

extension VisibilitySettingsPresenter: VisibilitySettingsViewOutput {
    func viewDidLoad() {
        guard flags.showVisibilitySettings else {
            router?.dismiss()
            return
        }
        guard let snapshot, snapshot.metadata.isOwner else {
            router?.dismiss()
            return
        }
        rebuildState()
        presentCurrentState()
        observeSnapshotChanges()
    }

    func viewDidToggleUseDefault(isOn: Bool) {
        guard isOn != usesDefaultOrder else { return }

        if isOn {
            handleUseDefaultToggleOn()
        } else {
            usesDefaultOrder = false
            if let cachedCustomVisibleVariants {
                visibleVariants = resolveVisible(
                    from: cachedCustomVisibleVariants,
                    available: availableVariants
                )
                hiddenVariants = resolveHidden(
                    from: hiddenVariants,
                    available: availableVariants,
                    visible: visibleVariants
                )
            }
            persistCurrentSelection()
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
        if hasActiveAlert(for: variant.type) {
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
        cacheCustomOrderIfNeeded()
        persistCurrentSelection()
        presentCurrentState()
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
        cacheCustomOrderIfNeeded()
        needsPersistVisibleReorder = true
        presentCurrentState()
    }

    func viewDidFinishReorderingVisibleItems() {
        guard needsPersistVisibleReorder else { return }
        needsPersistVisibleReorder = false
        cacheCustomOrderIfNeeded()
        persistCurrentSelection()
    }
}

// MARK: - Private helpers
private extension VisibilitySettingsPresenter {
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
        let currentVisibility = snapshot.metadata.measurementVisibility

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

        let baseVisible = (currentVisibility?.visibleVariants ?? defaultVisibleVariants(for: snapshot))
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
            cachedCustomVisibleVariants = visibleVariants
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
        return hidden
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
        let indicatorLookup = Dictionary(uniqueKeysWithValues: existingIndicators.map { ($0.variant, $0) })

        let previewIndicators: [RuuviTagCardSnapshotIndicatorData] = visibleVariants.map { variant in
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
    ) -> RuuviTagCardSnapshotIndicatorData {
        if let indicator = existing[variant] {
            return indicator
        }
        return placeholderIndicator(for: variant)
    }

    func placeholderIndicator(
        for variant: MeasurementDisplayVariant
    ) -> RuuviTagCardSnapshotIndicatorData {
        return RuuviTagCardSnapshotIndicatorData(
            variant: variant,
            value: placeholderValue(for: variant),
            unit: placeholderUnit(for: variant),
            isProminent: false,
            showSubscript: true,
            tintColor: nil,
            qualityState: nil
        )
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func placeholderValue(
        for variant: MeasurementDisplayVariant
    ) -> String {
        switch variant.type {
        case .temperature:
            switch resolvedTemperatureUnit(for: variant) {
            case .celsius:
                return "23.4"
            case .fahrenheit:
                return "74.1"
            case .kelvin:
                return "296"
            }
        case .humidity:
            switch resolvedHumidityUnit(for: variant) {
            case .percent:
                return "45"
            case .gm3:
                return "8.2"
            case .dew:
                return "12.0"
            }
        case .pressure:
            let unit = resolvedPressureUnit(for: variant)
            switch unit {
            case .millimetersOfMercury:
                return "760"
            case .inchesOfMercury:
                return "29.9"
            default:
                return "1013"
            }
        case .movementCounter:
            return "2"
        case .voltage:
            return "2.9"
        case .rssi:
            return "-62"
        case .accelerationX:
            return "0.02"
        case .accelerationY:
            return "-0.01"
        case .accelerationZ:
            return "1.00"
        case .aqi:
            return "42/500"
        case .co2:
            return "620"
        case .pm10:
            return "25"
        case .pm25:
            return "12"
        case .pm40:
            return "18"
        case .pm100:
            return "32"
        case .voc:
            return "0.24"
        case .nox:
            return "0.02"
        case .luminosity:
            return "320"
        case .soundInstant:
            return "43"
        case .soundPeak:
            return "67"
        case .soundAverage:
            return "38"
        case .txPower:
            return "-8"
        case .measurementSequenceNumber:
            return "512"
        default:
            return RuuviLocalization.na
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    func placeholderUnit(
        for variant: MeasurementDisplayVariant
    ) -> String {
        switch variant.type {
        case .temperature:
            return resolvedTemperatureUnit(for: variant).symbol
        case .humidity:
            switch resolvedHumidityUnit(for: variant) {
            case .percent:
                return "%"
            case .gm3:
                return RuuviLocalization.gm³
            case .dew:
                return resolvedTemperatureUnit(for: variant).symbol
            }
        case .pressure:
            return resolvedPressureUnit(for: variant).symbol
        case .movementCounter, .measurementSequenceNumber:
            return ""
        case .voltage:
            return RuuviLocalization.v
        case .rssi, .txPower:
            return "dBm"
        case .accelerationX, .accelerationY, .accelerationZ:
            return "g"
        case .aqi:
            return ""
        case .co2:
            return RuuviLocalization.unitCo2
        case .pm10:
            return RuuviLocalization.unitPm10
        case .pm25:
            return RuuviLocalization.unitPm25
        case .pm40:
            return RuuviLocalization.unitPm40
        case .pm100:
            return RuuviLocalization.unitPm100
        case .voc:
            return RuuviLocalization.unitVoc
        case .nox:
            return RuuviLocalization.unitNox
        case .luminosity:
            return RuuviLocalization.unitLuminosity
        case .soundInstant, .soundAverage, .soundPeak:
            return RuuviLocalization.unitSound
        default:
            return ""
        }
    }

    func resolvedTemperatureUnit(
        for variant: MeasurementDisplayVariant
    ) -> TemperatureUnit {
        variant.temperatureUnit ?? settings.temperatureUnit
    }

    func resolvedHumidityUnit(
        for variant: MeasurementDisplayVariant
    ) -> HumidityUnit {
        variant.humidityUnit ?? settings.humidityUnit
    }

    func resolvedPressureUnit(
        for variant: MeasurementDisplayVariant
    ) -> UnitPressure {
        variant.pressureUnit ?? settings.pressureUnit
    }

    func handleUseDefaultToggleOn() {
        guard let sensor else {
            usesDefaultOrder = true
            presentCurrentState()
            return
        }
        cachedCustomVisibleVariants = visibleVariants
        let defaultVisible = defaultVisibleVariants(for: sensor)
        let typeNamesNeedingConfirmation = measurementTypeNamesWithActiveAlertsWhenSwitchingToDefault(
            targetVisible: defaultVisible
        )

        let applyDefault: () -> Void = { [weak self] in
            guard let self else { return }
            self.usesDefaultOrder = true
            self.persistCurrentSelection()
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
            hiddenVariants.insert(variant, at: 0)
        }
        usesDefaultOrder = false
        cacheCustomOrderIfNeeded()
        persistCurrentSelection()
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
        guard let configuration = snapshot.alertData.alertConfigurations.first(
            where: { $0.key.isSameCase(as: type) }
        )?.value else {
            return false
        }
        return configuration.isActive
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

        let displayOrderCodes: [String]? = {
            guard !usesDefaultOrder else { return nil }
            let codes = visibleVariants.compactMap { variant in
                RuuviTagDataService.measurementCode(for: variant)
            }
            return codes.isEmpty ? nil : codes
        }()

        isSaving = true
        view?.setSaving(true)

        sensorPropertiesService
            .updateDisplaySettings(
                for: sensor,
                displayOrder: displayOrderCodes,
                defaultDisplayOrder: usesDefaultOrder
            )
            .on(success: { [weak self] settings in
                guard let self else { return }
                self.isSaving = false
                self.sensorSettings = settings
                self.view?.setSaving(false)
                self.updateMeasurementPreferenceCache(with: displayOrderCodes)
                self.applySelectionToSnapshot()
            }, failure: { [weak self] error in
                guard let self else { return }
                self.isSaving = false
                self.view?.setSaving(false)
                self.view?.showMessage(error.localizedDescription)
                self.rebuildState()
                self.presentCurrentState()
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

        let _ = snapshot.updateMeasurementVisibility(visibility)

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
        if usesDefaultOrder || codes?.isEmpty != false {
            RuuviTagDataService.clearMeasurementDisplayPreference(for: sensor.id)
        } else if let codes {
            let preference = RuuviTagDataService.MeasurementDisplayPreference(
                defaultDisplayOrder: false,
                displayOrderCodes: codes
            )
            RuuviTagDataService.setMeasurementDisplayPreference(
                preference,
                for: sensor.id
            )
        }
    }

    func cacheCustomOrderIfNeeded() {
        guard !usesDefaultOrder else { return }
        cachedCustomVisibleVariants = visibleVariants
    }

    func disableAlertIfNeeded(for variant: MeasurementDisplayVariant) {
        guard let snapshot, let sensor else { return }
        guard let alertType = variant.type.toAlertType() else { return }
        guard snapshot.getAlertConfig(for: variant.type)?.isActive == true else { return }
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

    func withAlertService(
        _ block: (RuuviTagAlertService, RuuviTagCardSnapshot, RuuviTagSensor) -> Void
    ) {
        guard let snapshot, let sensor else { return }
        RuuviTagServiceCoordinatorManager.shared.withCoordinator { coordinator in
            block(coordinator.services.alert, snapshot, sensor)
        }
    }
}
