import SwiftUI
import RuuviLocalization

private struct Constants {
    static let padding: CGFloat = 12
}

// MARK: - Settings Value Row
struct CardsSettingsSettingsValueRow<Trailing: View>: View {
    let title: String
    let value: String
    private let trailingContent: Trailing
    private let onTap: (() -> Void)?

    init(
        title: String,
        value: String,
        @ViewBuilder trailing: () -> Trailing,
        onTap: (() -> Void)? = nil
    ) {
        self.title = title
        self.value = value
        self.trailingContent = trailing()
        self.onTap = onTap
    }

    var body: some View {
        let content = HStack {
            Text(title)
                .foregroundStyle(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviHeadline())
            Spacer()
            Text(value)
                .foregroundStyle(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviBody())
            trailingContent
        }
        .padding(.horizontal, Constants.padding)
        .padding(.vertical, Constants.padding)
        .contentShape(Rectangle())

        if let onTap {
            content.onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}

extension CardsSettingsSettingsValueRow where Trailing == EmptyView {
    init(title: String, value: String) {
        self.init(title: title, value: value) {
            EmptyView()
        }
    }
}

// MARK: - Settings Navigation Row
struct SettingsNavigationRow: View {
    let title: String
    let value: String
    let onTap: () -> Void

    var body: some View {
        CardsSettingsSettingsValueRow(
            title: title,
            value: value,
            trailing: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            },
            onTap: onTap
        )
    }
}

// MARK: - Settings Divider
struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(
                RuuviColor.lineColor.swiftUIColor
            )
    }
}
