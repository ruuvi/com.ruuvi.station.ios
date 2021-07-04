import SwiftUI

struct ProgressBar: View {
    @Binding var value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(
                        width: geometry.size.width ,
                        height: geometry.size.height
                    )
                    .opacity(0.3)
                    .foregroundColor(RuuviColor.green)

                Rectangle()
                    .frame(
                        width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width),
                        height: geometry.size.height
                    )
                    .foregroundColor(RuuviColor.green)
                    .animation(.linear)
            }.cornerRadius(45.0)
        }
    }
}
