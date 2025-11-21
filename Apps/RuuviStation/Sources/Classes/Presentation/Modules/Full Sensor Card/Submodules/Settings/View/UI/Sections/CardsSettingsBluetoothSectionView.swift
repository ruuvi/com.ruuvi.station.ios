import SwiftUI
import RuuviLocalization

struct CardsSettingsBluetoothSectionView: View {
    @EnvironmentObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    private struct Constants {
        static let padding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let spacing: CGFloat = 8
        static let footerAlpha: CGFloat = 0.7
    }

    var body: some View {
        VStack(spacing: 0) {
            keepConnectionRow
            SettingsDivider().padding(.leading, Constants.padding)
            Text(state.keepConnectionDescription)
                .foregroundColor(
                    RuuviColor.textColor.swiftUIColor
                        .opacity(Constants.footerAlpha)
                )
                .font(.ruuviFootnote())
                .padding(.horizontal, Constants.padding)
                .padding(.vertical, Constants.verticalPadding)
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

        return HStack(spacing: Constants.spacing) {
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
        .padding(Constants.padding)
    }
}
