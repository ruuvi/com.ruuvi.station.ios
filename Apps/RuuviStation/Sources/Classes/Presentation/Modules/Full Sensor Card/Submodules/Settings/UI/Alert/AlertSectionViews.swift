import SwiftUI
import Combine
import UIKit
import RuuviLocalization
import RuuviOntology

struct AlertSectionsGroupView: View {
    @EnvironmentObject private var state: CardsSettingsState
    @EnvironmentObject private var actions: CardsSettingsActions

    var body: some View {
        VStack(spacing: 1) {
            AlertHeaderView()

            ForEach(state.alertSections) { section in
                AlertSectionRow(
                    model: section,
                    isExpanded: state.isAlertSectionExpanded(section.id),
                    onToggleSection: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            state.toggleAlertSection(section.id)
                        }
                    },
                    onToggleAlert: { isOn in
                        actions.didToggleAlert.send((section.alertType, isOn))
                    },
                    onRangeChange: { range, isFinal in
                        let change = AlertRangeChange(
                            alertType: section.alertType,
                            lowerBound: range.lowerBound,
                            upperBound: range.upperBound,
                            isFinal: isFinal
                        )
                        actions.didChangeAlertRange.send(change)
                    },
                    onEditDescription: {
                        actions.didRequestAlertDescriptionEdit.send(section.alertType)
                    },
                    onTapLimitEdit: {
                        actions.didRequestAlertLimitEdit.send(section.alertType)
                    },
                    onTapCloudDelay: {
                        actions.didTapCloudConnectionDelay.send(())
                    }
                )
            }
        }
    }
}

private struct AlertHeaderView: View {
    var body: some View {
        HStack {
            Text(RuuviLocalization.TagSettings.Label.Alerts.text.capitalized)
                .ruuviButtonLarge()
                .foregroundStyle(RuuviColor.dashboardIndicator.swiftUIColor)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor)
        .contentShape(Rectangle())
    }
}

struct AlertSectionRow: View {
    let model: CardsSettingsState.AlertSectionModel
    let isExpanded: Bool
    let onToggleSection: () -> Void
    let onToggleAlert: (Bool) -> Void
    let onRangeChange: (ClosedRange<Double>, Bool) -> Void
    let onEditDescription: () -> Void
    let onTapLimitEdit: () -> Void
    let onTapCloudDelay: () -> Void

    @State private var toggleValue: Bool
    @State private var sliderRange: ClosedRange<Double>?
    @ObservedObject private var blinkTimer = AlertBlinkTimer.shared

    init(
        model: CardsSettingsState.AlertSectionModel,
        isExpanded: Bool,
        onToggleSection: @escaping () -> Void,
        onToggleAlert: @escaping (Bool) -> Void,
        onRangeChange: @escaping (ClosedRange<Double>, Bool) -> Void,
        onEditDescription: @escaping () -> Void,
        onTapLimitEdit: @escaping () -> Void,
        onTapCloudDelay: @escaping () -> Void
    ) {
        self.model = model
        self.isExpanded = isExpanded
        self.onToggleSection = onToggleSection
        self.onToggleAlert = onToggleAlert
        self.onRangeChange = onRangeChange
        self.onEditDescription = onEditDescription
        self.onTapLimitEdit = onTapLimitEdit
        self.onTapCloudDelay = onTapCloudDelay

        _toggleValue = State(initialValue: model.configuration.isEnabled)
        _sliderRange = State(initialValue: model.configuration.sliderConfiguration?.selectedRange)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded {
                AlertSectionContentView(
                    model: model,
                    toggleValue: $toggleValue,
                    sliderRange: $sliderRange,
                    onToggleAlert: onToggleAlert,
                    onRangeChange: onRangeChange,
                    onEditDescription: onEditDescription,
                    onTapLimitEdit: onTapLimitEdit,
                    onTapCloudDelay: onTapCloudDelay
                )
            }
        }
        .background(RuuviColor.primary.swiftUIColor)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onChange(of: model.configuration.isEnabled) { newValue in
            toggleValue = newValue
        }
        .onChange(of: model.configuration.sliderConfiguration?.selectedRange) { newRange in
            if let newRange {
                sliderRange = newRange
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        AlertSectionHeader(
            model: model,
            isExpanded: isExpanded,
            alertIconImage: alertIconImage,
            alertIconColor: alertIconColor,
            alertIconAccessibilityLabel: alertIconAccessibilityLabel,
            alertIconOpacity: alertIconOpacity,
            mutedText: mutedText,
            onToggleSection: onToggleSection
        )
    }

    private var mutedText: String? {
        guard let date = model.headerState.mutedTill,
              date > Date() else {
            return nil
        }
        return AppDateFormatter.shared.shortTimeString(from: date)
    }

    private var alertIconImage: Image? {
        if let muted = model.headerState.mutedTill,
           muted > Date() {
            return RuuviAsset.iconAlertOff.swiftUIImage
        }

        guard model.headerState.isOn else {
            return nil
        }

        switch model.headerState.alertState {
        case .firing:
            return RuuviAsset.iconAlertActive.swiftUIImage
        case .registered:
            return RuuviAsset.iconAlertOn.swiftUIImage
        default:
            return nil
        }
    }

    private var alertIconColor: Color {
        if let muted = model.headerState.mutedTill,
           muted > Date() {
            return Color(RuuviColor.logoTintColor.color)
        }
        switch model.headerState.alertState {
        case .firing:
            return Color(RuuviColor.orangeColor.color)
        default:
            return RuuviColor.tintColor.swiftUIColor
        }
    }

    private var alertIconAccessibilityLabel: String {
        model.title
    }

    private var alertIconOpacity: Double {
        guard isAlertFiring else { return 1 }
        return blinkTimer.isVisible ? 1 : 0
    }

    private var isAlertFiring: Bool {
        model.headerState.alertState == .firing &&
            model.headerState.isOn &&
            !(model.headerState.mutedTill.map { $0 > Date() } ?? false)
    }
}

private struct AlertSectionContentView: View {
    let model: CardsSettingsState.AlertSectionModel
    @Binding var toggleValue: Bool
    @Binding var sliderRange: ClosedRange<Double>?

    let onToggleAlert: (Bool) -> Void
    let onRangeChange: (ClosedRange<Double>, Bool) -> Void
    let onEditDescription: () -> Void
    let onTapLimitEdit: () -> Void
    let onTapCloudDelay: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            if let notice = model.configuration.noticeText {
                AlertNoticeRow(text: notice)
            }

            AlertStatusRow(
                isOn: $toggleValue,
                isEnabled: model.isInteractionEnabled,
                showsStatusLabel: model.headerState.showStatusLabel,
                onToggle: onToggleAlert
            )

            if let descriptionTitle = customDescriptionTitle {
                SettingsDivider()
                Button(action: onEditDescription) {
                    AlertActionRow(
                        title: .plain(descriptionTitle),
                        icon: RuuviAsset.editPen.swiftUIImage
                    )
                }
                .buttonStyle(.plain)
            }

            if let limitText = limitDescriptionTitle {
                SettingsDivider()
                if model.configuration.showsLimitEditIcon {
                    Button(action: onTapLimitAction) {
                        AlertActionRow(
                            title: limitText,
                            icon: RuuviAsset.editPen.swiftUIImage
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    AlertActionRow(title: limitText, icon: nil)
                }
            }

            if let sliderConfig = model.configuration.sliderConfiguration {
                let displayConfig = sliderRange
                    .map { sliderConfig.withSelectedRange($0) } ?? sliderConfig
                AlertRangeSliderView(
                    configuration: displayConfig,
                    onRangeChange: { min, max in
                        self.sliderRange = min...max
                        onRangeChange(min...max, false)
                    },
                    onRangeChangeEnd: { min, max in
                        self.sliderRange = min...max
                        onRangeChange(min...max, true)
                    }
                )
                .disabled(!model.isInteractionEnabled)
                .opacity(model.isInteractionEnabled ? 1 : 0.4)
            }

            if let info = model.configuration.additionalInfo {
                SettingsDivider()
                AlertAdditionalInfoRow(text: info)
            }

            if let latest = model.configuration.latestMeasurement {
                AlertLatestMeasurementRow(text: latest)
            }
        }
        .background(RuuviColor.primary.swiftUIColor)
    }

    private var customDescriptionTitle: String? {
        if let customDescription = model.configuration.customDescriptionText,
           !customDescription.isEmpty {
            return customDescription
        }
        return RuuviLocalization.TagSettings.Alert.CustomDescription.placeholder
    }

    private var limitDescriptionTitle: AlertActionRowTitle? {
        guard let description = model.configuration.limitDescription else { return nil }
        switch description {
        case let .staticText(text):
            return .plain(text)
        case .sliderLocalized:
            guard let sliderConfig = model.configuration.sliderConfiguration else {
                return nil
            }
            let range = sliderRange ?? sliderConfig.selectedRange
            return LegacyAlertFormatter.sliderLimitTitle(
                lower: range.lowerBound,
                upper: range.upperBound
            )
        }
    }

    private var onTapLimitAction: () -> Void {
        switch model.alertType {
        case .cloudConnection:
            return onTapCloudDelay
        default:
            return onTapLimitEdit
        }
    }
}

private struct AlertSectionHeader: View {
    let model: CardsSettingsState.AlertSectionModel
    let isExpanded: Bool
    let alertIconImage: Image?
    let alertIconColor: Color
    let alertIconAccessibilityLabel: String
    let alertIconOpacity: Double
    let mutedText: String?
    let onToggleSection: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(model.title)
                .ruuviHeadline()
                .foregroundStyle(RuuviColor.dashboardIndicator.swiftUIColor)
                .multilineTextAlignment(.leading)

            Spacer()

            if let icon = alertIconImage {
                icon
                    .scaledToFit()
                    .foregroundColor(alertIconColor)
                    .accessibilityLabel(alertIconAccessibilityLabel)
                    .opacity(alertIconOpacity)
            }

            if let muted = mutedText {
                Text(muted)
                    .font(.ruuviFootnote())
                    .foregroundColor(RuuviColor.textColor.swiftUIColor.opacity(0.7))
            }

            RuuviAsset.arrowDropDown.swiftUIImage
                .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                .animation(.easeInOut(duration: 0.2), value: isExpanded)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(RuuviColor.tagSettingsItemHeaderColor.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleSection)
    }
}

// MARK: - Legacy formatting helpers
private enum LegacyAlertFormatter {
    private static let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }()

    private static let numberRegex = try? NSRegularExpression(pattern: "\\d+([.,]\\d+)?")
    private static let baseFont = UIFont.ruuviSubheadline()
    private static let boldFont = UIFont.mulish(.bold, size: 14)

    private static func numberString(from value: Double) -> String {
        let number = NSNumber(value: value)
        return numberFormatter.string(from: number) ?? "\(value)"
    }

    static func sliderLimitTitle(
        lower: Double,
        upper: Double
    ) -> AlertActionRowTitle {
        let lowerText = numberString(from: lower)
        let upperText = numberString(from: upper)
        if let attributed = attributedString(lowerText: lowerText, upperText: upperText) {
            return .attributed(attributed)
        } else {
            let fallback = RuuviLocalization.TagSettings.Alerts.description(lowerText, upperText)
            return .plain(fallback)
        }
    }

    private static func attributedString(
        lowerText: String,
        upperText: String
    ) -> AttributedString? {
        let message = RuuviLocalization.TagSettings.Alerts.description(lowerText, upperText)
        let attributed = NSMutableAttributedString(string: message)
        let fullRange = NSRange(location: 0, length: (message as NSString).length)
        attributed.addAttribute(.font, value: baseFont, range: fullRange)
        guard let numberRegex else {
            return AttributedString(attributed)
        }
        let matches = numberRegex.matches(in: message, options: [], range: fullRange)
        matches.forEach { match in
            attributed.addAttribute(.font, value: boldFont, range: match.range)
        }
        return AttributedString(attributed)
    }
}

private struct AlertStatusRow: View {
    @Binding var isOn: Bool
    let isEnabled: Bool
    let showsStatusLabel: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Spacer()
            RuuviSwitchRepresentable(
                isOn: $isOn,
                isEnabled: isEnabled,
                showsStatusLabel: showsStatusLabel,
                onToggle: { value in
                    isOn = value
                    onToggle(value)
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            let newValue = !isOn
            isOn = newValue
            onToggle(newValue)
        }
    }
}

final class AlertBlinkTimer: ObservableObject {
    static let shared = AlertBlinkTimer()

    @Published var isVisible: Bool = true

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = Timer.publish(
            every: 0.5,
            tolerance: 0.05,
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                self?.isVisible.toggle()
            }
        }
    }
}
