import SwiftUI

public struct ProgressBar: View {
    @Binding var value: Double
    
    public init(value: Binding<Double>) {
        self._value = value
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
                    .foregroundColor(.green) // TODO: @rinat RuuviColor.green

                Rectangle()
                    .frame(
                        width: min(CGFloat(self.value) * geometry.size.width, geometry.size.width),
                        height: geometry.size.height
                    )
                    .foregroundColor(.green) // TODO: @rinat RuuviColor.green
                    .animation(.linear)
            }.cornerRadius(6)
        }
    }
}
