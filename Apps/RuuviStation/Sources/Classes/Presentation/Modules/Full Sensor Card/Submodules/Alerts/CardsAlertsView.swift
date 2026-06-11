import SwiftUI
import RuuviLocalization

struct CardsAlertsView: View {
    @ObservedObject var state: CardsSettingsState
    let displayMode: CardsSettingsAlertDisplayMode
    let onNoCloudDataBannerTap: () -> Void
    @State private var pendingAnchorID: String?

    private struct Constants {
        static let sectionSpacing: CGFloat = 0.5
        static let bottomSpacerHeight: CGFloat = 44
        static let alertBottomAnchorID: String = "section-bottom"
        static let bottomSpacerID: String = "alerts-bottom-spacer"
    }

    private func alertAnchorID(for id: String) -> String {
        "\(id)-\(Constants.alertBottomAnchorID)"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: Constants.sectionSpacing) {
                    if state.showsAlertSettingsNoCloudDataBanner {
                        CardsAlertsNoCloudDataBanner(
                            onTap: onNoCloudDataBannerTap
                        )
                    }

                    if !state.alertSections.isEmpty {
                        CardsSettingsAlertSectionsGroupView(
                            showsHeader: false,
                            showsToggleInHeader: displayMode == .alerts,
                            displayMode: displayMode
                        )
                    }

                    Color.clear
                        .frame(height: Constants.bottomSpacerHeight)
                        .id(Constants.bottomSpacerID)
                }
            }
            .onChange(of: pendingAnchorID) { targetAnchor in
                guard let targetAnchor else { return }
                DispatchQueue.main.async {
                    withAnimation {
                        proxy.scrollTo(targetAnchor)
                    }
                    pendingAnchorID = nil
                }
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

private struct CardsAlertsNoCloudDataBanner: View {
    let onTap: () -> Void

    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let textColorOpacity: Double = 0.85
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(RuuviLocalization.TagSettings.Alerts.NoCloudDataBanner.text)
                .font(.ruuviFootnote())
                .foregroundStyle(
                    RuuviColor.textColor.swiftUIColor
                        .opacity(Constants.textColorOpacity)
                )
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RuuviColor.tagSettingsItemHeaderColor.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
