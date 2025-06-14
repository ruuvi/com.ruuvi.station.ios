import SwiftUI
import RuuviLocalization
import RuuviOntology

struct LowBatteryLevelView: View {

    var fontSize: CGFloat = 10
    var iconSize: CGFloat = 22
    var textColor: Color = RuuviColor.dashboardIndicator.swiftUIColor.opacity(0.5)
    var iconTint: Color = Color(RuuviColor.orangeColor.color)

    var body: some View {
        HStack(spacing: 6) {
            Text(RuuviLocalization.lowBattery)
                .font(.Muli(.regular, size: fontSize))
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
