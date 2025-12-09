import SwiftUI
import RuuviLocalization

struct CardsSettingsBasicInfoSectionView: View {
    let name: String
    let owner: String
    let shareStatus: String
    let ownersPlan: String
    let onEditName: () -> Void
    let onOwnerTap: () -> Void
    let onShareTap: () -> Void
    let onVisibleMeasurementsTap: () -> Void
    var showsOwner: Bool
    var showOwnersPlan: Bool
    var showsShare: Bool
    var visibleMeasurementsValue: String?
    var showsVisibleMeasurementsRow: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            SettingsDivider()

            CardsSettingsSettingsValueRow(
                title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
                value: name,
                trailing: {
                    RuuviAsset.editPen.swiftUIImage
                        .aspectRatio(
                            contentMode: .fit
                        )
                        .foregroundColor(
                            RuuviColor.tintColor.swiftUIColor
                        )
                },
                onTap: onEditName
            )

            if showsOwner || showsShare || showsVisibleMeasurementsRow {
                SettingsDivider()
            }

            if showsOwner {
                SettingsNavigationRow(
                    title: RuuviLocalization.TagSettings.NetworkInfo.owner,
                    value: owner,
                    onTap: onOwnerTap
                )

                if showsShare || showOwnersPlan || showsVisibleMeasurementsRow {
                    SettingsDivider()
                }
            }

            if showOwnersPlan {
                CardsSettingsSettingsValueRow(
                    title: RuuviLocalization.ownersPlan,
                    value: ownersPlan
                )

                if showsShare || showsVisibleMeasurementsRow {
                    SettingsDivider()
                }
            }

            if showsShare {
                SettingsNavigationRow(
                    title: RuuviLocalization.TagSettings.Share.title,
                    value: shareStatus,
                    onTap: onShareTap
                )

                if showsVisibleMeasurementsRow {
                    SettingsDivider()
                }
            }

            if showsVisibleMeasurementsRow {
                SettingsNavigationRow(
                    title: RuuviLocalization.visibleMeasurements,
                    value: visibleMeasurementsValue ?? RuuviLocalization.na,
                    onTap: onVisibleMeasurementsTap
                )
            }
        }
    }
}
