import SwiftUI
import RuuviOntology

enum FullSensorCardState {
    case measurement
    case graph
}

// MARK: - Main View
struct CardsTabBarLegacyView: View {
    @State private var sensorCardState: FullSensorCardState = .measurement
    @State private var alertState: AlertState = .empty
    @State private var isBlinking = false

    var onAlertTapped: () -> Void
    var onCardStateTapped: (FullSensorCardState) -> Void
    var onSettingsTapped: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                onAlertTapped()
            }) {
                BellIconView(alertState: $alertState, isBlinking: $isBlinking)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                if sensorCardState == .measurement {
                    sensorCardState = .graph
                } else {
                    sensorCardState = .measurement
                }
                onCardStateTapped(sensorCardState)
            }) {
                MiddleIconView(sensorCardState: sensorCardState)
            }
            .buttonStyle(PlainButtonStyle())

            Button(action: {
                onSettingsTapped()
            }) {
                Image(systemName: "gearshape.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundColor(.white)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .onAppear {
            // Start the blinking animation if alert is ringing
            if alertState == .firing {
                startBlinking()
            }
        }
        .onChange(of: alertState) { newState in
            if newState == .firing {
                startBlinking()
            } else {
                isBlinking = false
            }
        }
    }

    private func startBlinking() {
        isBlinking = true
    }
}

// MARK: - Bell Icon Component
struct BellIconView: View {
    @Binding var alertState: AlertState
    @Binding var isBlinking: Bool

    var body: some View {
        Image(systemName: iconName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 24, height: 24)
            .foregroundColor(.white)
            .opacity(opacity)
            .animation(blinkingAnimation, value: isBlinking)
    }

    private var iconName: String {
        switch alertState {
        case .empty:
            return "bell.slash"
        case .registered:
            return "bell.fill"
        case .firing:
            return "bell.badge.waveform"
        }
    }

    private var opacity: Double {
        isBlinking ? 0.1 : 1.0
    }

    private var blinkingAnimation: Animation? {
        guard alertState == .firing && isBlinking else { return nil }
        return Animation.easeInOut(duration: 0.5).repeatForever(autoreverses: true)
    }
}

// MARK: - Middle Icon Component
struct MiddleIconView: View {
    var sensorCardState: FullSensorCardState

    var body: some View {
        Image(
            systemName: sensorCardState == .measurement ? "thermometer" : "chart.bar.xaxis"
        )
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 24, height: 24)
        .foregroundColor(.white)
        // Disable default SwiftUI animations on the icon
        .animation(nil, value: sensorCardState)
        .transition(.opacity)
    }
}
