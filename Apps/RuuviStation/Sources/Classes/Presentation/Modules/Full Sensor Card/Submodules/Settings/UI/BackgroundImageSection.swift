import SwiftUI
import RuuviLocalization

struct BackgroundImageSection: View {
    let image: Image?
    let onImageTap: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            image?
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: GlobalHelpers.isDeviceTablet() ? 350 : 200)
                .clipped()

            HStack {
                Text(RuuviLocalization.TagSettings.BackgroundImageLabel.text)
                    .foregroundStyle(RuuviColor.textColor.swiftUIColor)
                    .font(.ruuviHeadline())
                Spacer()
                Image(systemName: "camera.fill")
                    .foregroundColor(RuuviColor.tintColor.swiftUIColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onImageTap()
        }
    }
}
