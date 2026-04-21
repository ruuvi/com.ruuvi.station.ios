import SwiftUI
import RuuviLocalization

public struct CardsSettingsNotesToggleButtonStyle: ButtonStyle {
    private struct Constants {
        static let horizontalPadding: CGFloat = 32
        static let verticalPadding: CGFloat = 10
        static let minWidth: CGFloat = 154
        static let borderWidth: CGFloat = 2
        static let pressedOpacity: Double = 0.55
        static let borderOpacity: Double = 0.35
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.ruuviButtonMedium())
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .foregroundStyle(
                RuuviColor.textColor.swiftUIColor
                    .opacity(configuration.isPressed ? Constants.pressedOpacity : 1)
            )
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .frame(minWidth: Constants.minWidth)
            .background(
                Capsule()
                    .fill(Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(
                        RuuviColor.textColor.swiftUIColor.opacity(Constants.borderOpacity),
                        lineWidth: Constants.borderWidth
                    )
            )
            .contentShape(Capsule())
    }
}
