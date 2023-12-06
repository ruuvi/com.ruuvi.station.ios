import UIKit
import SwiftUI

private struct ActivityPresenterAssets {
    static let activityOngoingDefault = "activity_ongoing_generic"
    static let activitySuccessDefault = "activity_success_generic"
    static let activityFailedDefault = "activity_failed_generic"

    static let activityLogoRuuvi = "ruuvi_activity_presenter_logo"
}

public struct ActivityPresenterView: View {
    @EnvironmentObject var stateHolder: ActivityPresenterStateHolder

    public var body: some View {
        VStack {
            if stateHolder.position == .bottom || stateHolder.position == .center {
                Spacer()
            }

            ActivityPresenterContentView(state: stateHolder.state)
                .padding([.leading, .trailing],
                         stateHolder.state == .dismiss ? 0 : 12)
                .padding([.top, .bottom],
                         stateHolder.state == .dismiss ? 0 : 12)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                .foregroundColor(.white)
                .transition(.scale.combined(with: .opacity))
                .opacity(stateHolder.state == .dismiss ? 0 : 1)

            if stateHolder.position == .top || stateHolder.position == .center {
                Spacer()
            }
        }
    }
}

struct ActivityPresenterContentView: View {
    let state: ActivityPresenterState

    var body: some View {
        HStack(spacing: 8) {
            if case .loading = state {
                ZStack {
                    contentImage?
                        .resizable()
                        .frame(width: 24, height: 24)
                    ActivitySpinnerViewRepresentable()
                        .frame(width: 30, height: 30)
                }
            } else {
                contentImage?
                    .resizable()
                    .frame(width: 12, height: 12)
            }
            Text(message)
        }
    }

    private var contentImage: Image? {
        switch state {
        case .loading:
            return Image(
                ActivityPresenterAssets.activityLogoRuuvi, 
                bundle: .pod(ActivityPresenterViewProvider.self)
            )
        case .success:
            return Image(systemName: "checkmark")
        case .failed:
            return Image(systemName: "xmark")
        default:
            return nil
        }
    }

    private var message: String {
        switch state {
        case .loading(let message):
            if let message = message {
                return message
            } else {
                return ActivityPresenterAssets
                    .activityOngoingDefault
                    .localized(for: ActivityPresenterViewProvider.self)
            }
        case .success(let message):
            if let message = message {
                return message
            } else {
                return ActivityPresenterAssets
                    .activitySuccessDefault
                    .localized(for: ActivityPresenterViewProvider.self)
            }
        case .failed(let message):
            if let message = message {
                return message
            } else {
                return ActivityPresenterAssets
                    .activityFailedDefault
                    .localized(for: ActivityPresenterViewProvider.self)
            }
        case .dismiss:
            return "" // Placeholder for dismiss state
        }
    }
}
