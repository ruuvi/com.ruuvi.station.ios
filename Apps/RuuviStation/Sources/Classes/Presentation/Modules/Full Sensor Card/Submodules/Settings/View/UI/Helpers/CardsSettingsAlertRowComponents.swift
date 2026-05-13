import SwiftUI
import RuuviLocalization

enum CardsSettingsAlertActionRowTitle {
    case plain(String)
    case attributed(AttributedString)
}

// MARK: CardsSettingsAlertActionRow
struct CardsSettingsAlertActionRow: View {
    let title: CardsSettingsAlertActionRowTitle
    let icon: Image?

    private struct Constants {
        static let spacing: CGFloat = 12
        static let leadingPadding: CGFloat = 14
        static let trailingPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 8
        static let rowHeight: CGFloat = 44
    }

    var body: some View {
        HStack(alignment: .center, spacing: Constants.spacing) {
            textContent
                .multilineTextAlignment(.leading)
            Spacer()
            if let icon {
                icon.foregroundColor(RuuviColor.tintColor.swiftUIColor)
            }
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(minHeight: Constants.rowHeight, alignment: .center)
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

// MARK: CardsSettingsModernAlertActionRow
struct CardsSettingsModernAlertActionRow: View {
    let title: CardsSettingsAlertActionRowTitle
    let icon: Image?

    private struct Constants {
        static let spacing: CGFloat = 12
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 4
        static let verticalPadding: CGFloat = 6
        static let rowHeight: CGFloat = 40
        static let actionSize: CGFloat = 32
    }

    var body: some View {
        HStack(alignment: .center, spacing: Constants.spacing) {
            textContent
                .multilineTextAlignment(.leading)
            Spacer()
            if let icon {
                icon.foregroundColor(RuuviColor.tintColor.swiftUIColor)
                    .frame(width: Constants.actionSize)
            }
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(minHeight: Constants.rowHeight, alignment: .center)
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

// MARK: CardsSettingsModernAlertCustomMessageRow
struct CardsSettingsModernAlertCustomMessageRow: View {
    let title: String
    let message: String
    let icon: Image?

    private struct Constants {
        static let spacing: CGFloat = 12
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 4
        static let verticalPadding: CGFloat = 6
        static let rowHeight: CGFloat = 40
        static let actionSize: CGFloat = 32
        static let messageOpacity: Double = 0.7
    }

    var body: some View {
        HStack(alignment: .center, spacing: Constants.spacing) {
            Text(title)
                .font(.ruuviSubheadline())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .multilineTextAlignment(.leading)

            Spacer(minLength: Constants.spacing)

            HStack(alignment: .center, spacing: Constants.spacing) {
                Text(message)
                    .font(.ruuviSubheadline())
                    .foregroundColor(
                        RuuviColor.textColor.swiftUIColor.opacity(Constants.messageOpacity)
                    )
                    .lineLimit(1)
                    .multilineTextAlignment(.trailing)

                if let icon {
                    icon.foregroundColor(RuuviColor.tintColor.swiftUIColor)
                        .frame(width: Constants.actionSize)
                }
            }
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(minHeight: Constants.rowHeight, alignment: .center)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
    }
}

// MARK: CardsSettingsAlertNoticeRow
struct CardsSettingsAlertNoticeRow: View {
    let text: String

    private struct Constants {
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 8
        static let verticalPadding: CGFloat = 8
        static let textColorOpacity: Double = 0.6
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.ruuviFootnote())
                .foregroundColor(
                    RuuviColor.textColor.swiftUIColor
                        .opacity(Constants.textColorOpacity)
                )
            Spacer()
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .padding(.vertical, Constants.verticalPadding)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

// MARK: CardsSettingsModernAlertNoticeRow
struct CardsSettingsModernAlertNoticeRow: View {
    let text: String

    private struct Constants {
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 4
        static let verticalPadding: CGFloat = 6
        static let textColorOpacity: Double = 0.6
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.ruuviFootnote())
                .foregroundColor(
                    RuuviColor.textColor.swiftUIColor
                        .opacity(Constants.textColorOpacity)
                )
            Spacer()
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .padding(.vertical, Constants.verticalPadding)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

// MARK: CardsSettingsAlertAdditionalInfoRow
struct CardsSettingsAlertAdditionalInfoRow: View {
    let text: String

    private struct Constants {
        static let padding: CGFloat = 14
        static let rowHeight: CGFloat = 44
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.ruuviFootnote())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
            Spacer()
        }
        .padding(.horizontal, Constants.padding)
        .frame(minHeight: Constants.rowHeight, alignment: .leading)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

// MARK: CardsSettingsModernAlertAdditionalInfoRow
struct CardsSettingsModernAlertAdditionalInfoRow: View {
    let text: String

    private struct Constants {
        static let leadingPadding: CGFloat = 12
        static let trailingPadding: CGFloat = 4
        static let rowHeight: CGFloat = 40
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.ruuviFootnote())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
            Spacer()
        }
        .padding(.leading, Constants.leadingPadding)
        .padding(.trailing, Constants.trailingPadding)
        .frame(minHeight: Constants.rowHeight, alignment: .leading)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
        .onTapGesture {}
    }
}

// MARK: CardsSettingsAlertLatestMeasurementRow
struct CardsSettingsAlertLatestMeasurementRow: View {
    let text: String

    private struct Constants {
        static let horizontalPadding: CGFloat = 14
        static let bottomPadding: CGFloat = 12
        static let textColorOpacity: Double = 0.6
    }

    var body: some View {
        HStack {
            Text(RuuviLocalization.latestMeasuredValue(text))
                .font(.ruuviFootnote())
                .foregroundColor(
                    RuuviColor.textColor.swiftUIColor.opacity(Constants.textColorOpacity)
                )
            Spacer()
        }
        .padding(.leading, Constants.horizontalPadding)
        .padding(.bottom, Constants.bottomPadding)
        .background(RuuviColor.primary.swiftUIColor)
        .contentShape(Rectangle())
    }
}
