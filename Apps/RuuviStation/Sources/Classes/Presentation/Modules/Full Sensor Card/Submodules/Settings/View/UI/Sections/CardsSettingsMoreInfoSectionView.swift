import SwiftUI
import UIKit
import RuuviLocalization

struct CardsSettingsMoreInfoSectionView: View {
    @EnvironmentObject private var state: CardsSettingsState
    @EnvironmentObject private var actions: CardsSettingsActions

    private struct Constants {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let fontSize: CGFloat = 14
        static let infoSymbol: String = "info.circle"
    }

    var body: some View {
        VStack(spacing: 0) {
            if state.shouldShowNoValuesIndicator {
                Button(action: {
                    actions.didTapNoValuesIndicator.send()
                }) {
                    HStack {
                        Text(RuuviLocalization.TagSettings.Label.NoValues.text)
                            .font(.ruuviFootnote())
                            .foregroundColor(RuuviColor.textColor.swiftUIColor)
                        Spacer()
                        Image(systemName: Constants.infoSymbol)
                            .font(.system(size: Constants.fontSize, weight: .semibold))
                            .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                    }
                    .padding(.horizontal, Constants.horizontalPadding)
                    .padding(.vertical, Constants.verticalPadding)
                }
                .buttonStyle(.plain)
                SettingsDivider()
            }

            SettingsDivider()

            ForEach(
                Array(state.moreInfoRows.enumerated()),
                id: \.element.id
            ) { _, element in
                Group {
                    if element.isTappable {
                        Button {
                            handle(action: element.action)
                        } label: {
                            CardsSettingsMoreInfoRow(row: element)
                        }
                        .buttonStyle(.plain)
                    } else {
                        CardsSettingsMoreInfoRow(row: element)
                    }
                }
            }
        }
        .background(.clear)
    }

    private func handle(
        action: CardsSettingsMoreInfoRowModel.Action
    ) {
        switch action {
        case .none:
            break
        case .macAddress:
            actions.didTapMoreInfoMacAddress.send()
        case .txPower:
            actions.didTapMoreInfoTxPower.send()
        case .measurementSequence:
            actions.didTapMoreInfoMeasurementSequence.send()
        }
    }
}

struct CardsSettingsMoreInfoRow: View {
    let row: CardsSettingsMoreInfoRowModel

    private struct Constants {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 8
        static let trailingPadding: CGFloat = 4
    }

    var body: some View {
        HStack {
            Text(row.title)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviSubheadline())
            Spacer()
            if let note = row.note, let noteColor = row.noteColor {
                Text(note)
                    .foregroundColor(noteColor)
                    .font(.ruuviSubheadline())
                    .padding(.trailing, Constants.trailingPadding)
            }
            Text(row.value)
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .font(.ruuviSubheadline())
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.vertical, Constants.verticalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(.clear)
    }
}
