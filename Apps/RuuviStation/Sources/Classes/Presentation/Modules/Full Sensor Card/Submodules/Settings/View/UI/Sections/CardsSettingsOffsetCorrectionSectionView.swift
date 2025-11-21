import SwiftUI
import UIKit
import RuuviLocalization

private struct Constants {
    static let padding: CGFloat = 12
    static let disabledOpacity: CGFloat = 0.3
    static let fontSize: CGFloat = 14
    static let chevronSymbol: String = "chevron.right"
}

struct CardsSettingsOffsetCorrectionSectionView: View {
    @EnvironmentObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        VStack(spacing: 0) {
            CardsSettingsOffsetCorrectionRow(
                title: RuuviLocalization.TagSettings.OffsetCorrection.temperature,
                value: state.temperatureOffset,
                isEnabled: state.hasLatestMeasurement,
                onTap: {
                    actions.didTapTemperatureOffset.send()
                }
            )

            if state.showHumidityOffset {
                SettingsDivider().padding(.leading, Constants.padding)

                CardsSettingsOffsetCorrectionRow(
                    title: RuuviLocalization.relativeHumidity,
                    value: state.humidityOffset,
                    isEnabled: state.hasLatestMeasurement && state.isHumidityOffsetVisible,
                    onTap: {
                        actions.didTapHumidityOffset.send()
                    }
                )
            }

            if state.showPressureOffset {
                SettingsDivider().padding(.leading, Constants.padding)

                CardsSettingsOffsetCorrectionRow(
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

struct CardsSettingsOffsetCorrectionRow: View {
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
                            RuuviColor.textColor.swiftUIColor.opacity(
                                Constants.disabledOpacity)
                    )
                    .font(.ruuviSubheadline())
                Spacer()
                Text(value)
                    .foregroundColor(isEnabled ? RuuviColor.textColor.swiftUIColor :
                            RuuviColor.textColor.swiftUIColor.opacity(
                                Constants.disabledOpacity)
                    )
                    .font(.ruuviSubheadline())
                Image(systemName: Constants.chevronSymbol)
                    .foregroundColor(
                        isEnabled ? .secondary : .secondary
                            .opacity(Constants.disabledOpacity)
                    )
                    .font(.system(size: Constants.fontSize, weight: .semibold))
            }
            .padding(.horizontal, Constants.padding)
            .padding(.vertical, Constants.padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .background(.clear)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
