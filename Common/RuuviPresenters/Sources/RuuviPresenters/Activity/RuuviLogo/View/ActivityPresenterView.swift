import RuuviLocalization
import SwiftUI
import UIKit

private enum ActivityPresenterAssets {
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
                .padding(
                    [.leading, .trailing],
                    stateHolder.state == .dismiss ? 0 : 12
                )
                .padding(
                    [.top, .bottom],
                    stateHolder.state == .dismiss ? 0 : 12
                )
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
            RuuviAsset.ruuviActivityPresenterLogo.swiftUIImage
        case .success:
            Image(systemName: "checkmark")
        case .failed:
            Image(systemName: "xmark")
        default:
            nil
        }
    }

    private var message: String {
        switch state {
        case let .loading(message):
            if let message {
                message
            } else {
                RuuviLocalization
                    .activityOngoingGeneric
            }
        case let .success(message):
            if let message {
                message
            } else {
                RuuviLocalization
                    .activitySuccessGeneric
            }
        case let .failed(message):
            if let message {
                message
            } else {
                RuuviLocalization
                    .activityFailedGeneric
            }
        case .dismiss:
            "" // Placeholder for dismiss state
        }
    }
}
