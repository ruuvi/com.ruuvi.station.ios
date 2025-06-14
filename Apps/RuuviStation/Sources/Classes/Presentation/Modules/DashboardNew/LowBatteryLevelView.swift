import SwiftUI
import RuuviLocalization
import RuuviOntology

struct LowBatteryLevelView: View {

    var fontSize: CGFloat = 10
    var iconSize: CGFloat = 22
    var textColor: Color = Color(
        .white.withAlphaComponent(0.8)
    )

    var iconTint: Color = Color(RuuviColor.orangeColor.color)

    var body: some View {
        HStack(spacing: 4) {
            Text(RuuviLocalization.lowBattery)
                .font(.custom("Muli-Regular", size: fontSize))
                .foregroundColor(textColor)
                .multilineTextAlignment(.trailing)

            Image(systemName: "battery.25")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .foregroundColor(iconTint)
        }
        .clipped()
    }
}
