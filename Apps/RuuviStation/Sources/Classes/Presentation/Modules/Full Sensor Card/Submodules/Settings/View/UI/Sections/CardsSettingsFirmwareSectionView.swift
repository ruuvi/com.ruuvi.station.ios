import SwiftUI
import UIKit
import RuuviLocalization

struct CardsSettingsFirmwareSectionView: View {
    @EnvironmentObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    private struct Constants {
        static let padding: CGFloat = 12
    }

    var body: some View {
        VStack(spacing: 0) {
            CardsSettingsSettingsValueRow(
                title: RuuviLocalization.TagSettings.Firmware.currentVersion,
                value: state.firmwareVersion
            )
            SettingsDivider().padding(.leading, Constants.padding)
            SettingsNavigationRow(
                title: RuuviLocalization.TagSettings.Firmware.updateFirmware,
                value: "",
                onTap: { actions.didTapFirmwareUpdate.send() }
            )
        }
        .background(.clear)
    }
}
