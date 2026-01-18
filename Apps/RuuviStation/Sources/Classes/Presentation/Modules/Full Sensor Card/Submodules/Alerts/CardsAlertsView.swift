import SwiftUI

struct CardsAlertsView: View {
    @ObservedObject var state: CardsSettingsState
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
                    if !state.alertSections.isEmpty {
                        CardsSettingsAlertSectionsGroupView(
                            showsHeader: false,
                            showsToggleInHeader: true
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
