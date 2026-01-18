import SwiftUI
import RuuviLocalization

// MARK: - Main View
struct CardsSettingsView: View {
    @ObservedObject var state: CardsSettingsState
    @EnvironmentObject var actions: CardsSettingsActions
    let showsAlertSections: Bool
    @State private var pendingAnchorID: String?

    init(
        state: CardsSettingsState,
        showsAlertSections: Bool = true
    ) {
        self.state = state
        self.showsAlertSections = showsAlertSections
    }

    private func sectionAnchorID(for id: String) -> String {
        "\(id)-\(Constants.bottomAnchorID)"
    }

    private func alertAnchorID(for id: String) -> String {
        "\(id)-\(Constants.alertBottomAnchorID)"
    }

    private struct Constants {
        static let sectionSpacing: CGFloat = 0.5
        static let bottomSpacerHeight: CGFloat = 44

        static let bottomAnchorID: String = "bottom-anchor"
        static let alertBottomAnchorID: String = "alert-bottom"
        static let bottomSpacerID: String = "settings-bottom-spacer"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Constants.sectionSpacing) {
                    CardsSettingsBackgroundImageSection(
                        image: state.backgroundImage,
                        onImageTap: {
                            actions.didTapBackgroundChange.send()
                        }
                    )

                    CardsSettingsBasicInfoSectionView(
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
                        onLedBrightnessTap: {
                            actions.didTapLedBrightnessRow.send()
                        },
                        showsOwner: state.showOwner,
                        showOwnersPlan: state.showOwnersPlan,
                        showsShare: state.showShare,
                        visibleMeasurementsValue: state.visibleMeasurementsValue,
                        ledBrightnessValue: state.ledBrightnessValue,
                        showsVisibleMeasurementsRow: state.showVisibleMeasurementsRow,
                        showsLedBrightnessRow: state.showLedBrightnessRow
                    )

                    if state.showBluetoothSection {
                        let bluetoothSection = CardsSettingsSection(
                            id: CardsSettingsSectionID.bluetooth.rawValue,
                            title: RuuviLocalization
                                .TagSettings.SectionHeader.BTConnection.title.capitalized,
                            isCollapsible: false,
                            content: { AnyView(CardsSettingsBluetoothSectionView()) }
                        )
                        CardsSettingsExpandableSectionRow(
                            section: bluetoothSection,
                            isExpanded: true,
                            isCollapsible: false,
                            onToggle: {},
                            content: {
                                bluetoothSection.content()
                            }
                        )
                    }

                    if showsAlertSections, !state.alertSections.isEmpty {
                        CardsSettingsAlertSectionsGroupView()
                    }
                    VStack(spacing: Constants.sectionSpacing) {
                        ForEach(state.settingsSections) { section in
                            let sectionID = section.id
                            let isExpanded = section.isCollapsible ?
                                state.expandedSections.contains(sectionID) : true
                            CardsSettingsExpandableSectionRow(
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

                    Color.clear.frame(
                        height: Constants.bottomSpacerHeight
                    ).id(Constants.bottomSpacerID)
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
