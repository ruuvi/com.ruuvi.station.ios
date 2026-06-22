// swiftlint:disable file_length

import SwiftUI
import Combine
import UIKit
import RuuviLocalization
import RuuviOntology

enum CardsSettingsAlertDisplayMode {
    // TODO: Remove legacy alert settings display mode when showNewSettings is fully rolled out.
    case legacySettings
    case alerts

    var legacyShowsAlertIcon: Bool {
        self == .legacySettings
    }
}

private enum CardsSettingsAlertLayout {
    static let headerLeadingPadding: CGFloat = 16
    static let headerTrailingPadding: CGFloat = 4
    static let headerVerticalPadding: CGFloat = 8
    static let headerContentSpacing: CGFloat = 8
    static let rowSpacing: CGFloat = 8
    static let summaryRowVerticalPadding: CGFloat = 4
    static let sliderLeadingPadding: CGFloat = 4
    static let actionSize: CGFloat = 32
    static let headerActionSize: CGFloat = 32
}

// MARK: CardsSettingsAlertSectionsGroupView
struct CardsSettingsAlertSectionsGroupView: View {
    @EnvironmentObject private var state: CardsSettingsState
    @EnvironmentObject private var actions: CardsSettingsActions
    let showsHeader: Bool
    let showsToggleInHeader: Bool
    let displayMode: CardsSettingsAlertDisplayMode

    init(
        showsHeader: Bool = true,
        showsToggleInHeader: Bool = false,
        displayMode: CardsSettingsAlertDisplayMode = .legacySettings
    ) {
        self.showsHeader = showsHeader
        self.showsToggleInHeader = showsToggleInHeader
        self.displayMode = displayMode
    }

    private struct Constants {
        static let sectionSpacing: CGFloat = 0.5
        static let animationDuration: TimeInterval = 0.2

        static let sectionBottomID: String = "section-bottom"
    }

    var body: some View {
        VStack(spacing: Constants.sectionSpacing) {
            if showsHeader {
                CardsSettingsAlertSectionGroupHeaderView()
            }

            ForEach(state.alertSections) { section in
                let sectionID = section.id
                CardsSettingsAlertSectionRow(
                    model: section,
                    isExpanded: state.isAlertSectionExpanded(sectionID),
                    showsToggleInHeader: showsToggleInHeader,
                    displayMode: displayMode,
                    onToggleSection: {
                        withAnimation(
                            .easeInOut(duration: Constants.animationDuration)
                        ) {
                            state.toggleAlertSection(sectionID)
                        }
                    },
                    onToggleAlert: { isOn in
                        actions.didToggleAlert.send((section.alertType, isOn))
                    },
                    onRangeChange: { range, isFinal in
                        let change = CardsSettingsAlertRangeChange(
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
                .id(sectionID)

                Color.clear
                    .frame(height: 0)
                    .id("\(sectionID)-\(Constants.sectionBottomID)")
            }
        }
    }
}

// MARK: CardsSettingsAlertSectionGroupHeaderView
private struct CardsSettingsAlertSectionGroupHeaderView: View {
    private let padding: CGFloat = 12

    var body: some View {
        HStack {
            Text(RuuviLocalization.TagSettings.Label.Alerts.text.capitalized)
                .ruuviButtonLarge()
                .foregroundStyle(RuuviColor.dashboardIndicator.swiftUIColor)
            Spacer()
        }
        .padding(padding)
        .background(RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor)
        .contentShape(Rectangle())
    }
}

struct CardsSettingsAlertShortcutSectionView: View {
    @EnvironmentObject private var actions: CardsSettingsActions

    private enum Constants {
        static let sectionSpacing: CGFloat = 0.5
        static let rowPadding: CGFloat = 12
    }

    var body: some View {
        VStack(spacing: Constants.sectionSpacing) {
            CardsSettingsAlertSectionGroupHeaderView()

            Button(action: {
                actions.didTapAlertsShortcut.send()
            }) {
                HStack(alignment: .center, spacing: Constants.rowPadding) {
                    Text(RuuviLocalization.TagSettings.Label.AlertsTopMenuHint.text)
                        .font(.ruuviBody())
                        .foregroundStyle(RuuviColor.textColor.swiftUIColor)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: Constants.rowPadding)

                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(Constants.rowPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(RuuviColor.primary.swiftUIColor)
        }
    }
}

// MARK: CardsSettingsAlertSectionRow
struct CardsSettingsAlertSectionRow: View {
    let model: CardsSettingsAlertSectionModel
    let isExpanded: Bool
    let showsToggleInHeader: Bool
    let displayMode: CardsSettingsAlertDisplayMode
    let onToggleSection: () -> Void
    let onToggleAlert: (Bool) -> Void
    let onRangeChange: (ClosedRange<Double>, Bool) -> Void
    let onEditDescription: () -> Void
    let onTapLimitEdit: () -> Void
    let onTapCloudDelay: () -> Void

    @State private var toggleValue: Bool
    @State private var sliderRange: ClosedRange<Double>?
    @ObservedObject private var blinkTimer = CardsSettingsAlertBlinkTimer.shared

    init(
        model: CardsSettingsAlertSectionModel,
        isExpanded: Bool,
        showsToggleInHeader: Bool,
        displayMode: CardsSettingsAlertDisplayMode,
        onToggleSection: @escaping () -> Void,
        onToggleAlert: @escaping (Bool) -> Void,
        onRangeChange: @escaping (ClosedRange<Double>, Bool) -> Void,
        onEditDescription: @escaping () -> Void,
        onTapLimitEdit: @escaping () -> Void,
        onTapCloudDelay: @escaping () -> Void
    ) {
        self.model = model
        self.isExpanded = isExpanded
        self.showsToggleInHeader = showsToggleInHeader
        self.displayMode = displayMode
        self.onToggleSection = onToggleSection
        self.onToggleAlert = onToggleAlert
        self.onRangeChange = onRangeChange
        self.onEditDescription = onEditDescription
        self.onTapLimitEdit = onTapLimitEdit
        self.onTapCloudDelay = onTapCloudDelay

        _toggleValue = State(
            initialValue: model.configuration.isEnabled
        )
        _sliderRange = State(
            initialValue: model.configuration.sliderConfiguration?.selectedRange
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if isExpanded {
                CardsSettingsAlertSectionContentView(
                    model: model,
                    showsToggleInHeader: showsToggleInHeader,
                    displayMode: displayMode,
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
        .onChange(of: model.configuration.isEnabled) { newValue in
            toggleValue = newValue
        }
        .onChange(
            of: model.configuration.sliderConfiguration?.selectedRange
        ) { newRange in
            if let newRange {
                sliderRange = newRange
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        CardsSettingsAlertSectionRowHeader(
            model: model,
            isExpanded: isExpanded,
            legacyAlertIconImage: displayMode.legacyShowsAlertIcon ? legacyAlertIconImage : nil,
            legacyAlertIconColor: legacyAlertIconColor,
            legacyAlertIconAccessibilityLabel: legacyAlertIconAccessibilityLabel,
            legacyAlertIconOpacity: legacyAlertIconOpacity,
            rangeSummary: headerRangeSummary,
            mutedText: mutedText,
            showsToggleInHeader: showsToggleInHeader,
            displayMode: displayMode,
            latestMeasurementIsHighlighted: isAlertFiring,
            toggleValue: $toggleValue,
            isToggleEnabled: model.isInteractionEnabled,
            showsStatusLabel: model.headerState.showStatusLabel,
            onToggleAlert: onToggleAlert,
            onToggleSection: onToggleSection
        )
    }

    private var headerRangeSummary: String? {
        guard displayMode == .alerts else {
            return nil
        }
        if let headerSummaryText = model.configuration.headerSummaryText {
            return headerSummaryText
        }
        guard let sliderConfiguration = model.configuration.sliderConfiguration else {
            return nil
        }
        let displayConfiguration = sliderRange
            .map { sliderConfiguration.withSelectedRange($0) } ?? sliderConfiguration
        return displayConfiguration.selectedBoundsSummary
    }

    private var mutedText: String? {
        guard let date = model.headerState.mutedTill,
              date > Date() else {
            return nil
        }
        return AppDateFormatter.shared.shortTimeString(from: date)
    }

    // TODO: Remove legacy alert icon helpers when showNewSettings is fully rolled out.
    private var legacyAlertIconImage: Image? {
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

    private var legacyAlertIconColor: Color {
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

    private var legacyAlertIconAccessibilityLabel: String {
        model.legacyTitle
    }

    private var legacyAlertIconOpacity: Double {
        guard isAlertFiring else { return 1 }
        return blinkTimer.isVisible ? 1 : 0
    }

    private var isAlertFiring: Bool {
        model.headerState.alertState == .firing &&
            model.headerState.isOn &&
            !(model.headerState.mutedTill.map { $0 > Date() } ?? false)
    }
}

// MARK: CardsSettingsAlertSectionContentView
private struct CardsSettingsAlertSectionContentView: View {
    let model: CardsSettingsAlertSectionModel
    let showsToggleInHeader: Bool
    let displayMode: CardsSettingsAlertDisplayMode
    @Binding var toggleValue: Bool
    @Binding var sliderRange: ClosedRange<Double>?

    let onToggleAlert: (Bool) -> Void
    let onRangeChange: (ClosedRange<Double>, Bool) -> Void
    let onEditDescription: () -> Void
    let onTapLimitEdit: () -> Void
    let onTapCloudDelay: () -> Void

    private let disabledOpacity: Double = 0.4

    var body: some View {
        switch displayMode {
        case .legacySettings:
            legacySettingsContent
        case .alerts:
            alertsContent
        }
    }

    // TODO: Remove legacy settings content when showNewSettings is fully rolled out.
    private var legacySettingsContent: some View {
        VStack(spacing: 0) {
            if let notice = model.configuration.noticeText {
                CardsSettingsLegacyNoticeRow(text: notice)
            }

            if !showsToggleInHeader {
                CardsSettingsAlertEnableRow(
                    isOn: $toggleValue,
                    isEnabled: model.isInteractionEnabled,
                    showsStatusLabel: model.headerState.showStatusLabel,
                    onToggle: onToggleAlert,
                    isCompact: false
                )
                .opacity(editableOpacity)
            }

            if let descriptionTitle = customDescriptionTitle {
                SettingsDivider()
                Button(action: onEditDescription) {
                    CardsSettingsLegacyActionRow(
                        title: .plain(descriptionTitle),
                        icon: RuuviAsset.editPen.swiftUIImage
                    )
                }
                .buttonStyle(.plain)
                .disabled(!model.isInteractionEnabled)
                .opacity(editableOpacity)
            }

            if let limitText = limitDescriptionTitle {
                SettingsDivider()
                if model.configuration.showsLimitEditIcon {
                    Button(action: onTapLimitAction) {
                        CardsSettingsLegacyActionRow(
                            title: limitText,
                            icon: RuuviAsset.editPen.swiftUIImage
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isInteractionEnabled)
                    .opacity(editableOpacity)
                } else {
                    CardsSettingsLegacyActionRow(title: limitText, icon: nil)
                }
            }

            if let sliderConfig = model.configuration.sliderConfiguration {
                let displayConfig = sliderRange
                    .map { sliderConfig.withSelectedRange($0) } ?? sliderConfig
                CardsSettingsAlertRangeSliderView(
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
                .opacity(editableOpacity)
            }

            if let info = model.configuration.additionalInfo {
                SettingsDivider()
                CardsSettingsLegacyInfoRow(text: info)
            }

            if let latest = model.configuration.latestMeasurement {
                CardsSettingsLegacyLatestRow(text: latest)
            }
        }
        .background(RuuviColor.primary.swiftUIColor)
    }

    private var alertsContent: some View {
        VStack(spacing: 0) {
            if let rangeNotice = rangeNoticeText {
                CardsSettingsAlertNoticeRow(text: rangeNotice)
            }

            if let notice = model.configuration.noticeText {
                CardsSettingsAlertNoticeRow(text: notice)
            }

            if let sliderConfig = model.configuration.sliderConfiguration {
                let displayConfig = sliderRange
                    .map { sliderConfig.withSelectedRange($0) } ?? sliderConfig
                HStack(alignment: .center, spacing: CardsSettingsAlertLayout.rowSpacing) {
                    CardsSettingsAlertRangeSliderView(
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
                    .frame(maxWidth: .infinity)

                    if model.configuration.showsLimitEditIcon {
                        Button(action: onTapLimitAction) {
                            RuuviAsset.editPen.swiftUIImage
                                .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                                .frame(width: CardsSettingsAlertLayout.actionSize)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, CardsSettingsAlertLayout.sliderLeadingPadding)
                .padding(.trailing, CardsSettingsAlertLayout.headerTrailingPadding)
                .background(RuuviColor.primary.swiftUIColor)
                .disabled(!model.isInteractionEnabled)
                .opacity(editableOpacity)
            } else if let limitText = limitDescriptionTitle {
                SettingsDivider()
                if model.configuration.showsLimitEditIcon {
                    Button(action: onTapLimitAction) {
                        CardsSettingsAlertActionRow(
                            title: limitText,
                            icon: RuuviAsset.editPen.swiftUIImage
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.isInteractionEnabled)
                    .opacity(editableOpacity)
                } else {
                    CardsSettingsAlertActionRow(
                        title: limitText,
                        icon: nil
                    )
                }
            }

            if let info = model.configuration.additionalInfo {
                SettingsDivider()
                CardsSettingsAlertInfoRow(text: info)
            }

            if let descriptionTitle = customDescriptionTitle {
                SettingsDivider()
                Button(action: onEditDescription) {
                    CardsSettingsAlertCustomMessageRow(
                        title: RuuviLocalization.TagSettings.Alert.CustomDescription.title,
                        message: descriptionTitle,
                        icon: RuuviAsset.editPen.swiftUIImage
                    )
                }
                .buttonStyle(.plain)
                .disabled(!model.isInteractionEnabled)
                .opacity(editableOpacity)
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

    private var limitDescriptionTitle: CardsSettingsAlertActionRowTitle? {
        guard let description = model.configuration.limitDescription else { return nil }
        switch description {
        case let .staticText(text):
            return .plain(text)
        case .sliderLocalized:
            guard let sliderConfig = model.configuration.sliderConfiguration else {
                return nil
            }
            let range = sliderRange ?? sliderConfig.selectedRange
            return CardsSettingsAlertRangeFormatter.sliderLimitTitle(
                lower: range.lowerBound,
                upper: range.upperBound
            )
        }
    }

    private var rangeNoticeText: String? {
        guard case .sliderLocalized? = model.configuration.limitDescription,
              let sliderConfig = model.configuration.sliderConfiguration else {
            return nil
        }
        let range = sliderRange ?? sliderConfig.selectedRange
        let displayConfig = sliderConfig.withSelectedRange(range)
        let text = RuuviLocalization.TagSettings.Alerts.description(
            displayConfig.selectedLowerDisplay,
            displayConfig.selectedUpperDisplay
        )
        return text.hasSuffix(".") ? text : "\(text)."
    }

    private var onTapLimitAction: () -> Void {
        switch model.alertType {
        case .cloudConnection:
            return onTapCloudDelay
        default:
            return onTapLimitEdit
        }
    }

    private var editableOpacity: Double {
        model.isInteractionEnabled ? 1 : disabledOpacity
    }
}

// MARK: CardsSettingsAlertSectionRowHeader
private struct CardsSettingsAlertSectionRowHeader: View {
    let model: CardsSettingsAlertSectionModel
    let isExpanded: Bool
    let legacyAlertIconImage: Image?
    let legacyAlertIconColor: Color
    let legacyAlertIconAccessibilityLabel: String
    let legacyAlertIconOpacity: Double
    let rangeSummary: String?
    let mutedText: String?
    let showsToggleInHeader: Bool
    let displayMode: CardsSettingsAlertDisplayMode
    let latestMeasurementIsHighlighted: Bool
    @Binding var toggleValue: Bool
    let isToggleEnabled: Bool
    let showsStatusLabel: Bool
    let onToggleAlert: (Bool) -> Void
    let onToggleSection: () -> Void

    private struct Constants {
        static let spacing: CGFloat = 12
        static let rotatedArrowAngle: CGFloat = 180
        static let muteTextOpacity: Double = 0.7
    }

    var body: some View {
        Group {
            if showsToggleInHeader {
                compactHeader
            } else {
                legacyRegularHeader
            }
        }
        .padding(.leading, headerLeadingPadding)
        .padding(.trailing, headerTrailingPadding)
        .padding(.vertical, headerVerticalPadding)
        .background(RuuviColor.tagSettingsItemHeaderColor.swiftUIColor)
    }

    // TODO: Remove legacy regular header when showNewSettings is fully rolled out.
    private var legacyRegularHeader: some View {
        HStack(spacing: headerControlSpacing) {
            HStack(spacing: headerControlSpacing) {
                Text(model.legacyTitle)
                    .ruuviHeadline()
                    .foregroundStyle(RuuviColor.dashboardIndicator.swiftUIColor)
                    .multilineTextAlignment(.leading)

                Spacer()

                if let icon = legacyAlertIconImage {
                    icon
                        .scaledToFit()
                        .foregroundColor(legacyAlertIconColor)
                        .accessibilityLabel(legacyAlertIconAccessibilityLabel)
                        .opacity(legacyAlertIconOpacity)
                }

                if let muted = mutedText {
                    Text(muted)
                        .font(.ruuviFootnote())
                        .foregroundColor(
                            RuuviColor.textColor.swiftUIColor.opacity(Constants.muteTextOpacity)
                        )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggleSection)

            dropdownArrow
        }
    }

    private var compactHeader: some View {
        VStack(alignment: .leading, spacing: headerContentSpacing) {
            HStack(spacing: headerControlSpacing) {
                HStack(spacing: headerControlSpacing) {
                    compactHeaderTitle
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if let icon = legacyAlertIconImage {
                        icon
                            .scaledToFit()
                            .foregroundColor(legacyAlertIconColor)
                            .accessibilityLabel(legacyAlertIconAccessibilityLabel)
                            .opacity(legacyAlertIconOpacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleSection)

                if !showsToggleInSummaryRow {
                    compactToggle
                    dropdownArrow
                }
            }
            if showsSummaryRow {
                HStack(alignment: .center, spacing: headerControlSpacing) {
                    if let rangeSummary {
                        Text(rangeSummary)
                            .font(.ruuviFootnote())
                            .foregroundColor(
                                RuuviColor.textColor.swiftUIColor.opacity(Constants.muteTextOpacity)
                            )
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .contentShape(Rectangle())
                            .onTapGesture(perform: onToggleSection)
                    }

                    Spacer(minLength: headerControlSpacing)

                    if showsToggleInSummaryRow {
                        compactToggle
                            .fixedSize(horizontal: true, vertical: false)

                        dropdownArrow
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, CardsSettingsAlertLayout.summaryRowVerticalPadding)
            }
            if let muted = mutedText {
                Text(muted)
                    .font(.ruuviFootnote())
                    .foregroundColor(
                        RuuviColor.textColor.swiftUIColor.opacity(Constants.muteTextOpacity)
                    )
            }
        }
    }

    private var showsSummaryRow: Bool {
        rangeSummary != nil || showsToggleInSummaryRow
    }

    private var showsToggleInSummaryRow: Bool {
        displayMode == .alerts
    }

    private var compactToggle: some View {
        CardsSettingsAlertEnableRow(
            isOn: $toggleValue,
            isEnabled: isToggleEnabled,
            showsStatusLabel: showsStatusLabel,
            onToggle: onToggleAlert,
            isCompact: true
        )
    }

    private var headerLeadingPadding: CGFloat {
        switch displayMode {
        case .legacySettings:
            return legacyHeaderLeadingPadding
        case .alerts:
            return CardsSettingsAlertLayout.headerLeadingPadding
        }
    }

    private var headerTrailingPadding: CGFloat {
        switch displayMode {
        case .legacySettings:
            return legacyHeaderTrailingPadding
        case .alerts:
            return CardsSettingsAlertLayout.headerTrailingPadding
        }
    }

    private var headerVerticalPadding: CGFloat {
        switch displayMode {
        case .legacySettings:
            return legacyHeaderVerticalPadding
        case .alerts:
            return CardsSettingsAlertLayout.headerVerticalPadding
        }
    }

    private var headerContentSpacing: CGFloat {
        switch displayMode {
        case .legacySettings:
            return legacyHeaderContentSpacing
        case .alerts:
            return CardsSettingsAlertLayout.headerContentSpacing
        }
    }

    private var headerControlSpacing: CGFloat {
        switch displayMode {
        case .legacySettings:
            return legacyHeaderControlSpacing
        case .alerts:
            return CardsSettingsAlertLayout.rowSpacing
        }
    }

    // TODO: Remove legacy header metrics when showNewSettings is fully rolled out.
    private var legacyHeaderLeadingPadding: CGFloat {
        Constants.spacing
    }

    private var legacyHeaderTrailingPadding: CGFloat {
        Constants.spacing
    }

    private var legacyHeaderVerticalPadding: CGFloat {
        Constants.spacing
    }

    private var legacyHeaderContentSpacing: CGFloat {
        Constants.spacing
    }

    private var legacyHeaderControlSpacing: CGFloat {
        Constants.spacing
    }

    @ViewBuilder
    private var compactHeaderTitle: some View {
        switch displayMode {
        case .legacySettings:
            legacyCompactHeaderTitle
        case .alerts:
            compactTitleText
        }
    }

    @ViewBuilder
    private var dropdownArrow: some View {
        switch displayMode {
        case .legacySettings:
            legacyDropdownArrow
        case .alerts:
            RuuviAsset.arrowDropDown.swiftUIImage
                .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                .rotationEffect(
                    .degrees(isExpanded ? Constants.rotatedArrowAngle : 0)
                )
                .frame(width: CardsSettingsAlertLayout.headerActionSize)
                .contentShape(Rectangle())
                .onTapGesture(perform: onToggleSection)
        }
    }

    // TODO: Remove legacy compact header title when showNewSettings is fully rolled out.
    private var legacyCompactHeaderTitle: some View {
        Text(model.legacyTitle)
            .ruuviHeadline()
            .foregroundStyle(RuuviColor.dashboardIndicator.swiftUIColor)
    }

    // TODO: Remove legacy dropdown arrow when showNewSettings is fully rolled out.
    private var legacyDropdownArrow: some View {
        RuuviAsset.arrowDropDown.swiftUIImage
            .foregroundColor(RuuviColor.tintColor.swiftUIColor)
            .rotationEffect(
                .degrees(isExpanded ? Constants.rotatedArrowAngle : 0)
            )
            .onTapGesture(perform: onToggleSection)
    }

    private var compactTitleText: Text {
        guard displayMode == .alerts,
              let latest = model.configuration.latestMeasurementDisplay else {
            return Text(model.title)
                .ruuviHeadline()
                .foregroundColor(RuuviColor.dashboardIndicator.swiftUIColor)
        }

        let latestColor = latestMeasurementIsHighlighted
            ? RuuviColor.orangeColor.color
            : RuuviColor.dashboardIndicator.color
        let suffixText = latest.suffix.map {
            "\(latest.separator)\($0))"
        } ?? ")"

        return Text("\(model.title) (")
            .ruuviHeadline()
            .foregroundColor(RuuviColor.dashboardIndicator.swiftUIColor)
            + Text(latest.value)
            .ruuviHeadline()
            .foregroundColor(Color(latestColor))
            + Text(suffixText)
            .ruuviHeadline()
            .foregroundColor(RuuviColor.dashboardIndicator.swiftUIColor)
    }
}

// MARK: CardsSettingsAlertEnableRow
private struct CardsSettingsAlertEnableRow: View {
    @Binding var isOn: Bool
    let isEnabled: Bool
    let showsStatusLabel: Bool
    let onToggle: (Bool) -> Void
    let isCompact: Bool

    private struct Constants {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 14
    }

    var body: some View {
        HStack {
            if !isCompact {
                Spacer()
            }
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
        .padding(.horizontal, isCompact ? 0 : Constants.horizontalPadding)
        .padding(.vertical, isCompact ? 0 : Constants.verticalPadding)
        .background(isCompact ? Color.clear : RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isEnabled else { return }
            let newValue = !isOn
            isOn = newValue
            onToggle(newValue)
        }
    }
}

// swiftlint:enable file_length
