import Foundation
import Combine
import SwiftUI
import RuuviLocalization
import RuuviService
import RuuviOntology

enum TagSettingsSectionIdentifier: Hashable {
    case general
    case connectivity
    case alerts(AlertType)
    case alertOverview
    case calibration
    case moreInfo
    case firmware
    case remove
}

@MainActor
final class TagSettingsState: ObservableObject {
    // MARK: - Snapshot
    @Published var snapshot: RuuviTagCardSnapshot

    // MARK: - UI State
    @Published var expandedSections: Set<TagSettingsSectionIdentifier> = []
    @Published var isRenamingSensor: Bool = false
    @Published var isBackgroundPickerPresented: Bool = false
    @Published var alertConfigurationContext: AlertConfigurationContext?

    // MARK: - Dependencies
    private let formatter: TagSettingsFormatter

    init(
        snapshot: RuuviTagCardSnapshot,
        formatter: TagSettingsFormatter = DefaultTagSettingsFormatter()
    ) {
        self.snapshot = snapshot
        self.formatter = formatter
    }
}

extension TagSettingsState {
    struct AlertConfigurationContext: Identifiable, Equatable {
        let id: TagSettingsSectionIdentifier
        let type: AlertType
    }
}

extension TagSettingsState {
    var sensorNamePlaceholder: String {
        formatter.defaultName(for: snapshot)
    }

    var shareSummary: String {
        formatter.shareSummary(
            sharedTo: snapshot.ownership.sharedTo,
            maxShareCount: snapshot.ownership.maxShareCount
        )
    }

    var ownersPlanDisplay: String? {
        snapshot.ownership.ownersPlan
    }

    var ownerDisplay: String {
        formatter.ownerDisplayName(
            owner: snapshot.ownership.ownerName,
            isOwner: snapshot.metadata.isOwner
        )
    }

    var temperatureOffsetDisplay: String? {
        formatter.temperatureOffset(snapshot.calibration.temperatureOffset)
    }

    var humidityOffsetDisplay: String? {
        formatter.humidityOffset(snapshot.calibration.humidityOffset)
    }

    var pressureOffsetDisplay: String? {
        formatter.pressureOffset(snapshot.calibration.pressureOffset)
    }
}

// MARK: - Formatting
protocol TagSettingsFormatter {
    func defaultName(for snapshot: RuuviTagCardSnapshot) -> String
    func shareSummary(sharedTo: [String], maxShareCount: Int?) -> String
    func ownerDisplayName(owner: String?, isOwner: Bool) -> String
    func temperatureOffset(_ value: Double?) -> String?
    func humidityOffset(_ value: Double?) -> String?
    func pressureOffset(_ value: Double?) -> String?
}

struct DefaultTagSettingsFormatter: TagSettingsFormatter {
    private let measurementService: RuuviServiceMeasurement?

    init(
        measurementService: RuuviServiceMeasurement? = AppAssembly.shared.assembler.resolver.resolve(
            RuuviServiceMeasurement.self
        )
    ) {
        self.measurementService = measurementService
    }

    func defaultName(for snapshot: RuuviTagCardSnapshot) -> String {
        if let mac = snapshot.identifierData.mac?.value {
            return mac
        }
        if let luid = snapshot.identifierData.luid?.value {
            return luid
        }
        return RuuviLocalization.na
    }

    func shareSummary(sharedTo: [String], maxShareCount: Int?) -> String {
        guard !sharedTo.isEmpty else {
            return RuuviLocalization.TagSettings.NotShared.title
        }
        return RuuviLocalization.sharedToX(sharedTo.count, maxShareCount ?? sharedTo.count)
    }

    func ownerDisplayName(owner: String?, isOwner: Bool) -> String {
        if isOwner {
            return "You"
        }
        return owner ?? RuuviLocalization.TagSettings.General.Owner.none
    }

    func temperatureOffset(_ value: Double?) -> String? {
        guard let measurementService else { return nil }
        guard let value else { return nil }
        return measurementService.temperatureOffsetCorrectionString(for: value)
    }

    func humidityOffset(_ value: Double?) -> String? {
        guard let measurementService else { return nil }
        guard let value else { return nil }
        return measurementService.humidityOffsetCorrectionString(for: value)
    }

    func pressureOffset(_ value: Double?) -> String? {
        guard let measurementService else { return nil }
        guard let value else { return nil }
        return measurementService.pressureOffsetCorrectionString(for: value)
    }
}
