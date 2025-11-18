import SwiftUI
import RuuviLocalization

// MARK: - Main View
struct CardsSettingsView: View {
    @ObservedObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions
    @State private var pendingAnchorID: String?

    private func sectionAnchorID(for id: String) -> String {
        "\(id)-bottom-anchor"
    }

    private func alertAnchorID(for id: String) -> String {
        "\(id)-alert-bottom"
    }

    var body: some View {
        ScrollViewReader { proxy in
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
                        BluetoothSectionView()
                    }

                    if !state.alertSections.isEmpty {
                        AlertSectionsGroupView()
                    }

                    VStack(spacing: 1) {
                        ForEach(state.settingsSections) { section in
                            let sectionID = section.id
                            let isExpanded = section.isCollapsible ?
                                state.expandedSections.contains(sectionID) : true
                            ExpandableSectionRow(
                                section: section,
                                isExpanded: isExpanded,
                                isCollapsible: section.isCollapsible,
                                onToggle: {
                                    state.toggleSection(sectionID)
                                },
                                content: {
                                    section.content()
                                }
                            )
                            .id(sectionID)

                            Color.clear
                                .frame(height: 0)
                                .id(sectionAnchorID(for: sectionID))
                        }
                    }

                    Color.clear
                        .frame(height: 44)
                        .id("settings-bottom-spacer")
                }
            }
            .onChange(of: pendingAnchorID) { targetAnchor in
                guard let targetAnchor else { return }
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(
                            targetAnchor
                        )
                    }
                    pendingAnchorID = nil
                }
            }
            .onChange(of: state.lastExpandedSectionID) { targetID in
                guard let targetID else { return }
                pendingAnchorID = sectionAnchorID(for: targetID)
                state.clearLastExpandedSectionID()
            }
            .onChange(of: state.lastExpandedAlertID) { targetID in
                guard let targetID else { return }
                pendingAnchorID = alertAnchorID(for: targetID)
                state.clearLastExpandedAlertID()
            }
        }
        .environmentObject(state)
    }
}
