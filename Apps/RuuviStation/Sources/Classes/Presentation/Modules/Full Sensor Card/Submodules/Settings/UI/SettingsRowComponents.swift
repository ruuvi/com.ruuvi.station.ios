import SwiftUI
import RuuviLocalization

// MARK: - Settings Value Row
struct SettingsValueRow<Trailing: View>: View {
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
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .contentShape(Rectangle())

        if let onTap {
            content.onTapGesture(perform: onTap)
        } else {
            content
        }
    }
}

extension SettingsValueRow where Trailing == EmptyView {
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
        SettingsValueRow(
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

// MARK: - Section Header
struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .bold()
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(Color(red: 0.93, green: 0.96, blue: 0.96))
    }
}
