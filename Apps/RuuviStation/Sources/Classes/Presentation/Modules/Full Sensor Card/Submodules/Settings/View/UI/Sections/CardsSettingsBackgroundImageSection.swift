import SwiftUI
import RuuviLocalization

struct CardsSettingsBackgroundImageSection: View {
    let image: Image?
    let onImageTap: () -> Void

    private struct Constants {
        static let imageHeight: CGFloat = GlobalHelpers.isDeviceTablet() ? 350 : 200
        static let padding: CGFloat = 12
        static let cameraSymbol: String = "camera.fill"
    }

    var body: some View {
        VStack(spacing: 0) {
            image?
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: Constants.imageHeight)
                .clipped()

            HStack {
                Text(RuuviLocalization.TagSettings.BackgroundImageLabel.text)
                    .foregroundStyle(RuuviColor.textColor.swiftUIColor)
                    .font(.ruuviHeadline())
                Spacer()
                Image(systemName: Constants.cameraSymbol)
                    .foregroundColor(RuuviColor.tintColor.swiftUIColor)
            }
            .padding(.horizontal, Constants.padding)
            .padding(.vertical, Constants.padding)
        }
        .background(.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onImageTap()
        }
    }
}
