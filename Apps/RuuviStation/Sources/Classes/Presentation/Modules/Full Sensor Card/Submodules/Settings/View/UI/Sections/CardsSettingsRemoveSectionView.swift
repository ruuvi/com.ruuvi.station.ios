import SwiftUI
import UIKit
import RuuviLocalization

struct CardsSettingsRemoveSectionView: View {
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        SettingsNavigationRow(
            title: RuuviLocalization.TagSettings.RemoveThisSensor.title,
            value: "",
            onTap: { actions.didTapRemove.send() }
        )
    }
}
