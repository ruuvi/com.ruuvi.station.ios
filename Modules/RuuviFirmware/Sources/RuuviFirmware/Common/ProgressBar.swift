import RuuviLocalization
import SwiftUI

public struct ProgressBar: View {
    @Binding var value: Double

    public init(value: Binding<Double>) {
        _value = value
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .opacity(0.3)
                    .foregroundColor(RuuviColor.green.swiftUIColor)

                Rectangle()
                    .frame(
                        width: min(CGFloat(value) * geometry.size.width, geometry.size.width),
                        height: geometry.size.height
                    )
                    .foregroundColor(RuuviColor.green.swiftUIColor)
                    .animation(.linear)
            }.cornerRadius(6)
        }
    }
}
