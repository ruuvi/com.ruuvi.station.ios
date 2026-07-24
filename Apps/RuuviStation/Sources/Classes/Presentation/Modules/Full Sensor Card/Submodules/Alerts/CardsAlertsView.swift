import SwiftUI
import RuuviLocalization

struct CardsAlertsView: View {
    @ObservedObject var state: CardsSettingsState
    let displayMode: CardsSettingsAlertDisplayMode
    let onAlertDeliveryPromptTap: (CardsAlertsDeliveryPromptDestination) -> Void
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
                    if let prompt = state.alertDeliveryPrompt {
                        CardsAlertsDeliveryPromptView(
                            prompt: prompt,
                            onTap: {
                                onAlertDeliveryPromptTap(prompt.destination)
                            }
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

private struct CardsAlertsDeliveryPromptView: View {
    let prompt: CardsAlertsDeliveryPrompt
    let onTap: () -> Void

    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 12
        static let textColorOpacity: Double = 0.85
        static let contentSpacing: CGFloat = 12
        static let buttonHorizontalPadding: CGFloat = 25
        static let buttonVerticalPadding: CGFloat = 12
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.contentSpacing) {
            Text(prompt.message)
                .font(.ruuviFootnote())
                .foregroundStyle(
                    RuuviColor.textColor.swiftUIColor
                        .opacity(Constants.textColorOpacity)
                )
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Button(action: onTap) {
                Text(prompt.buttonTitle)
                    .font(.ruuviButtonMedium())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, Constants.buttonHorizontalPadding)
                    .padding(.vertical, Constants.buttonVerticalPadding)
                    .background(
                        Capsule()
                            .fill(RuuviColor.tintColor.swiftUIColor)
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RuuviColor.tagSettingsItemHeaderColor.swiftUIColor)
    }
}
