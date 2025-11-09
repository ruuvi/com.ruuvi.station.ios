import SwiftUI
import UIKit
import RuuviLocalization

struct OffsetCorrectionView: View {
    @EnvironmentObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        VStack(spacing: 0) {
            OffsetCorrectionRow(
                title: RuuviLocalization.TagSettings.OffsetCorrection.temperature,
                value: state.temperatureOffset,
                isEnabled: state.hasLatestMeasurement,
                onTap: {
                    actions.didTapTemperatureOffset.send()
                }
            )

            if state.showHumidityOffset {
                SettingsDivider().padding(.leading, 12)

                OffsetCorrectionRow(
                    title: RuuviLocalization.relativeHumidity,
                    value: state.humidityOffset,
                    isEnabled: state.hasLatestMeasurement && state.isHumidityOffsetVisible,
                    onTap: {
                        actions.didTapHumidityOffset.send()
                    }
                )
            }

            if state.showPressureOffset {
                SettingsDivider().padding(.leading, 12)

                OffsetCorrectionRow(
                    title: RuuviLocalization.pressure,
                    value: state.pressureOffset,
                    isEnabled: state.hasLatestMeasurement && state.isPressureOffsetVisible,
                    onTap: {
                        actions.didTapPressureOffset.send()
                    }
                )
            }
        }
        .background(.clear)
    }
}

struct OffsetCorrectionRow: View {
    let title: String
    let value: String
    let isEnabled: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: {
            if isEnabled {
                onTap()
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(isEnabled ? RuuviColor.textColor.swiftUIColor :
                            RuuviColor.textColor.swiftUIColor.opacity(0.3))
                    .font(.ruuviSubheadline())
                Spacer()
                Text(value)
                    .foregroundColor(isEnabled ? RuuviColor.textColor.swiftUIColor :
                            RuuviColor.textColor.swiftUIColor.opacity(0.3))
                    .font(.ruuviSubheadline())
                Image(systemName: "chevron.right")
                    .foregroundColor(isEnabled ? .secondary : .secondary.opacity(0.3))
                    .font(.system(size: 14, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(.clear)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct MoreInfoRow: View {
    let row: CardsSettingsState.MoreInfoRowModel

    var body: some View {
        HStack {
            Text(row.title)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviSubheadline())
            Spacer()
            if let note = row.note, let noteColor = row.noteColor {
                Text(note)
                    .foregroundColor(noteColor)
                    .font(.ruuviSubheadline())
                    .padding(.trailing, 4)
            }
            Text(row.value)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviSubheadline())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(.clear)
    }
}

struct FirmwareSectionView: View {
    @EnvironmentObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        VStack(spacing: 0) {
            SettingsValueRow(
                title: RuuviLocalization.TagSettings.Firmware.currentVersion,
                value: state.firmwareVersion
            )
            SettingsDivider().padding(.leading, 12)
            SettingsNavigationRow(
                title: RuuviLocalization.TagSettings.Firmware.updateFirmware,
                value: "",
                onTap: { actions.didTapFirmwareUpdate.send() }
            )
        }
        .background(.clear)
    }
}

struct RemoveSectionView: View {
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        SettingsNavigationRow(
            title: RuuviLocalization.TagSettings.RemoveThisSensor.title,
            value: "",
            onTap: { actions.didTapRemove.send() }
        )
    }
}

struct BluetoothSectionView: View {
    @EnvironmentObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        VStack(spacing: 0) {
            keepConnectionRow
            SettingsDivider().padding(.leading, 12)
            Text(state.keepConnectionDescription)
                .foregroundColor(RuuviColor.textColor.swiftUIColor.opacity(0.7))
                .font(.ruuviFootnote())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.clear)
    }

    private var keepConnectionRow: some View {
        let binding = Binding(
            get: { state.isKeepConnectionOn },
            set: { newValue in
                state.setKeepConnectionDisplay(isOn: newValue)
                actions.didToggleKeepConnection.send(newValue)
            }
        )

        return HStack(spacing: 8) {
            Text(state.keepConnectionStatusText)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviHeadline())
                .multilineTextAlignment(.leading)

            Spacer()

            if state.isKeepConnectionInProgress {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(RuuviColor.tintColor.swiftUIColor)
            }

            RuuviSwitchRepresentable(
                isOn: binding,
                isEnabled: state.isKeepConnectionToggleEnabled,
                showsStatusLabel: state.showKeepConnectionStatusLabel,
                onToggle: { value in
                    state.setKeepConnectionDisplay(isOn: value)
                    actions.didToggleKeepConnection.send(value)
                }
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}
