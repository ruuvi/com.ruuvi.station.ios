import RuuviLocalization
import SwiftUI

public struct RuuviBoardView: View {
    @State private var isPortrait = false
    public init() {}

    public var body: some View {
        HStack {
            if isPortrait {
                RuuviAsset.ruuvitagB8AndOlderButtonLocation.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Spacer()
                RuuviAsset.ruuvitagB8AndOlderButtonLocation.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .frame(width: 300, height: 147)
                Spacer()
            }
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            guard let scene = UIApplication().firstKeyScene else { return }
            isPortrait = scene.interfaceOrientation.isPortrait
        }
    }
}

private class RuuviFirmwareDummyClass {}
