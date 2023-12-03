import SwiftUI

public struct RuuviBoardView: View {
    @State private var isPortrait = false
    private let boardImageName = "ruuvitag-b8-and-older-button-location"
    public init() {}

    public var body: some View {
        HStack {
            if isPortrait {
                Image(boardImageName, bundle: .pod(RuuviFirmwareDummyClass.self))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Spacer()
                Image(boardImageName, bundle: .pod(RuuviFirmwareDummyClass.self))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaledToFit()
                    .frame(width: 300, height: 147)
                Spacer()
            }
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            guard let scene = UIApplication.shared.windows.first?.windowScene else { return }
            self.isPortrait = scene.interfaceOrientation.isPortrait
        }
    }
}

private class RuuviFirmwareDummyClass {
}
