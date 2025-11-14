import SwiftUI
import RuuviLocalization

enum AlertActionRowTitle {
    case plain(String)
    case attributed(AttributedString)
}

struct AlertActionRow: View {
    let title: AlertActionRowTitle
    let icon: Image?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            textContent
                .multilineTextAlignment(.leading)
            Spacer()
            if let icon {
                icon.foregroundColor(RuuviColor.tintColor.swiftUIColor)
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.vertical, 8)
        .frame(minHeight: 44, alignment: .center)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var textContent: some View {
        switch title {
        case let .plain(value):
            Text(value)
                .font(.ruuviSubheadline())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
        case let .attributed(value):
            Text(value)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
        }
    }
}

struct AlertNoticeRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.ruuviFootnote())
                .foregroundColor(RuuviColor.textColor.swiftUIColor.opacity(0.6))
            Spacer()
        }
        .padding(.leading, 12)
        .padding(.trailing, 8)
        .padding(.vertical, 8)
        .background(RuuviColor.primary.swiftUIColor)
    }
}

struct AlertAdditionalInfoRow: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.ruuviFootnote())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
            Spacer()
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .frame(minHeight: 44, alignment: .leading)
        .background(RuuviColor.primary.swiftUIColor)
    }
}

struct AlertLatestMeasurementRow: View {
    let text: String

    var body: some View {
        HStack {
            Text(RuuviLocalization.latestMeasuredValue(text))
                .font(.ruuviFootnote())
                .foregroundColor(RuuviColor.textColor.swiftUIColor.opacity(0.5))
            Spacer()
        }
        .padding(.leading, 14)
        .padding(.trailing, 16)
        .padding(.bottom, 12)
        .background(RuuviColor.primary.swiftUIColor)
    }
}
