import SwiftUI
import RuuviLocalization

// MARK: - Main View
struct CardsSettingsView: View {
    @ObservedObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 1) {
                BackgroundImageSection(
                    image: state.backgroundImage,
                    onImageTap: {
                        actions.didTapBackgroundChange.send()
                    }
                )

                BasicInfoSectionView(
                    name: state.name,
                    owner: state.ownerName,
                    shareStatus: state.shareSummary,
                    ownersPlan: state.ownersPlan,
                    onEditName: {
                        actions.didTapSnapshotName.send()
                    },
                    onOwnerTap: {
                        actions.didTapOwnerRow.send()
                    },
                    onShareTap: {
                        actions.didTapShareRow.send()
                    },
                    onVisibleMeasurementsTap: {
                        actions.didTapVisibleMeasurementsRow.send()
                    },
                    showsOwner: state.showOwner,
                    showOwnersPlan: state.showOwnersPlan,
                    showsShare: state.showShare,
                    visibleMeasurementsValue: state.visibleMeasurementsValue,
                    showsVisibleMeasurementsRow: state.showVisibleMeasurementsRow
                )

                if state.showBluetoothSection {
                    let bluetoothSection = SettingsSection(
                        id: "bluetooth",
                        title: RuuviLocalization
                            .TagSettings.SectionHeader.BTConnection.title.capitalized,
                        isCollapsible: false,
                        content: { AnyView(BluetoothSectionView()) }
                    )
                    ExpandableSectionRow(
                        section: bluetoothSection,
                        isExpanded: true,
                        isCollapsible: false,
                        onToggle: {},
                        content: {
                            bluetoothSection.content()
                        }
                    )
                }

                if !state.alertSections.isEmpty {
                    AlertSectionsGroupView()
                }

                // Additional Settings Sections
                VStack(spacing: 1) {
                    ForEach(state.settingsSections) { section in
                        ExpandableSectionRow(
                            section: section,
                            isExpanded: section.isCollapsible ?
                                state.expandedSections.contains(section.id) : true,
                            isCollapsible: section.isCollapsible,
                            onToggle: {
                                state.toggleSection(section.id)
                            },
                            content: {
                                section.content()
                            }
                        )
                    }
                }
            }
        }
        .environmentObject(state)
    }
}
