// swiftlint:disable file_length

import SwiftUI
import Combine
import UIKit
import RuuviLocalization
import RuuviOntology

// MARK: CardsSettingsAlertSectionsGroupView
struct CardsSettingsAlertSectionsGroupView: View {
    @EnvironmentObject private var state: CardsSettingsState
    @EnvironmentObject private var actions: CardsSettingsActions

    private struct Constants {
        static let sectionSpacing: CGFloat = 0.5
        static let animationDuration: TimeInterval = 0.2

        static let sectionBottomID: String = "section-bottom"
    }

    var body: some View {
        VStack(spacing: Constants.sectionSpacing) {
            CardsSettingsAlertSectionGroupHeaderView()

            ForEach(state.alertSections) { section in
                let sectionID = section.id
                CardsSettingsAlertSectionRow(
                    model: section,
                    isExpanded: state.isAlertSectionExpanded(sectionID),
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

// MARK: CardsSettingsAlertSectionRow
struct CardsSettingsAlertSectionRow: View {
    let model: CardsSettingsAlertSectionModel
    let isExpanded: Bool
    let onToggleSection: () -> Void
    let onToggleAlert: (Bool) -> Void
    let onRangeChange: (ClosedRange<Double>, Bool) -> Void
    let onEditDescription: () -> Void
    let onTapLimitEdit: () -> Void
    let onTapCloudDelay: () -> Void

    @State private var toggleValue: Bool
    @State private var sliderRange: ClosedRange<Double>?
    @ObservedObject private var blinkTimer = CardsSettingsAlertBlinkTimer.shared

    private let animationDuration: TimeInterval = 0.2

    init(
        model: CardsSettingsAlertSectionModel,
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
        .animation(
            .easeInOut(duration: animationDuration),
            value: isExpanded
        )
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

// MARK: CardsSettingsAlertSectionContentView
private struct CardsSettingsAlertSectionContentView: View {
    let model: CardsSettingsAlertSectionModel
    @Binding var toggleValue: Bool
    @Binding var sliderRange: ClosedRange<Double>?

    let onToggleAlert: (Bool) -> Void
    let onRangeChange: (ClosedRange<Double>, Bool) -> Void
    let onEditDescription: () -> Void
    let onTapLimitEdit: () -> Void
    let onTapCloudDelay: () -> Void

    private let disabledOpacity: Double = 0.4

    var body: some View {
        VStack(spacing: 0) {
            if let notice = model.configuration.noticeText {
                CardsSettingsAlertNoticeRow(text: notice)
            }

            CardsSettingsAlertEnableRow(
                isOn: $toggleValue,
                isEnabled: model.isInteractionEnabled,
                showsStatusLabel: model.headerState.showStatusLabel,
                onToggle: onToggleAlert
            )

            if let descriptionTitle = customDescriptionTitle {
                SettingsDivider()
                Button(action: onEditDescription) {
                    CardsSettingsAlertActionRow(
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
                        CardsSettingsAlertActionRow(
                            title: limitText,
                            icon: RuuviAsset.editPen.swiftUIImage
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    CardsSettingsAlertActionRow(title: limitText, icon: nil)
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
                .opacity(model.isInteractionEnabled ? 1 : disabledOpacity)
            }

            if let info = model.configuration.additionalInfo {
                SettingsDivider()
                CardsSettingsAlertAdditionalInfoRow(text: info)
            }

            if let latest = model.configuration.latestMeasurement {
                CardsSettingsAlertLatestMeasurementRow(text: latest)
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

    private var onTapLimitAction: () -> Void {
        switch model.alertType {
        case .cloudConnection:
            return onTapCloudDelay
        default:
            return onTapLimitEdit
        }
    }
}

// MARK: CardsSettingsAlertSectionRowHeader
private struct CardsSettingsAlertSectionRowHeader: View {
    let model: CardsSettingsAlertSectionModel
    let isExpanded: Bool
    let alertIconImage: Image?
    let alertIconColor: Color
    let alertIconAccessibilityLabel: String
    let alertIconOpacity: Double
    let mutedText: String?
    let onToggleSection: () -> Void

    private struct Constants {
        static let spacing: CGFloat = 12
        static let rotatedArrowAngle: CGFloat = 180
        static let animationDuration: CGFloat = 0.2
        static let muteTextOpacity: Double = 0.7
    }

    var body: some View {
        HStack(spacing: Constants.spacing) {
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
                    .foregroundColor(
                        RuuviColor.textColor.swiftUIColor.opacity(Constants.muteTextOpacity)
                    )
            }

            RuuviAsset.arrowDropDown.swiftUIImage
                .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                .rotationEffect(
                    .degrees(isExpanded ? Constants.rotatedArrowAngle : 0)
                )
                .animation(
                    .easeInOut(
                        duration: Constants.animationDuration
                    ),
                    value: isExpanded
                )
        }
        .padding(Constants.spacing)
        .background(RuuviColor.tagSettingsItemHeaderColor.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggleSection)
    }
}

// MARK: CardsSettingsAlertEnableRow
private struct CardsSettingsAlertEnableRow: View {
    @Binding var isOn: Bool
    let isEnabled: Bool
    let showsStatusLabel: Bool
    let onToggle: (Bool) -> Void

    private struct Constants {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 14
    }

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
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
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

// swiftlint:enable file_length
