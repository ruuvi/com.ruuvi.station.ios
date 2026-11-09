import SwiftUI
import RuuviLocalization

struct CardsSettingsBackgroundImageSection: View {
    let image: Image?
    let onImageTap: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private struct Constants {
        static let regularImageHeight: CGFloat = 350
        static let compactImageHeight: CGFloat = 200
        static let padding: CGFloat = 12
        static let cameraSymbol: String = "camera.fill"
    }

    /// 350pt in the regular layout (iPad), 200pt otherwise (iPhone, narrow or short windows).
    private var imageHeight: CGFloat {
        RuuviLayoutClass(horizontal: horizontalSizeClass, vertical: verticalSizeClass).isRegular
            ? Constants.regularImageHeight
            : Constants.compactImageHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            if let image {
                // Keep the photo's aspect ratio from widening the settings content.
                Color.clear
                    .frame(height: imageHeight)
                    .overlay {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    }
                    .clipped()
            }

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
