import RuuviLocalization
import SwiftUI

/// Where the button is on RuuviTag B8 and older, shown above the firmware update instructions.
///
/// The picture sits in a centered 300 x 147 box at every size class, as it always did when the
/// screen appeared. The layout never depends on the orientation: only when the width it is given is
/// narrower than the box (a narrow window) does the box scale down, keeping its shape, so the
/// picture is never cut off.
///
/// Only the top and bottom are padded. The fixed box used to overflow its 16pt side padding in
/// narrower columns (most iPhones in the firmware sheet), so the side margins are left to the
/// centering; that keeps the box 300 x 147 wherever the column is at least 300pt wide.
public struct RuuviBoardView: View {
    private static let boxSize = CGSize(width: 300, height: 147)

    public init() {}

    public var body: some View {
        Color.clear
            .aspectRatio(Self.boxSize.width / Self.boxSize.height, contentMode: .fit)
            .frame(maxWidth: Self.boxSize.width)
            .overlay {
                RuuviAsset.ruuvitagB8AndOlderButtonLocation.swiftUIImage
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
    }
}

private class RuuviFirmwareDummyClass {}
