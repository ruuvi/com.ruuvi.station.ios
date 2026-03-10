import SwiftUI
import RuuviLocalization

struct CardsSettingsBasicInfoSectionView: View {
    let name: String
    let owner: String
    let shareStatus: String
    let ownersPlan: String
    let onEditName: () -> Void
    let onOwnerTap: () -> Void
    let onShareTap: () -> Void
    let onVisibleMeasurementsTap: () -> Void
    let onLedBrightnessTap: () -> Void
    let onNotesTap: () -> Void
    var showsOwner: Bool
    var showOwnersPlan: Bool
    var showsShare: Bool
    var visibleMeasurementsValue: String?
    var ledBrightnessValue: String?
    var showsVisibleMeasurementsRow: Bool = false
    var showsLedBrightnessRow: Bool = false
    var notes: String = ""
    var isNotesEditable: Bool = false

    private var notesTitle: String {
        "Notes"
    }

    private var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SettingsDivider()

            CardsSettingsSettingsValueRow(
                title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
                value: name,
                trailing: {
                    RuuviAsset.editPen.swiftUIImage
                        .aspectRatio(
                            contentMode: .fit
                        )
                        .foregroundColor(
                            RuuviColor.tintColor.swiftUIColor
                        )
                },
                onTap: onEditName
            )

            SettingsDivider()

            if showsOwner {
                SettingsNavigationRow(
                    title: RuuviLocalization.TagSettings.NetworkInfo.owner,
                    value: owner,
                    onTap: onOwnerTap
                )

                SettingsDivider()
            }

            if showOwnersPlan {
                CardsSettingsSettingsValueRow(
                    title: RuuviLocalization.ownersPlan,
                    value: ownersPlan
                )

                SettingsDivider()
            }

            if showsShare {
                SettingsNavigationRow(
                    title: RuuviLocalization.TagSettings.Share.title,
                    value: shareStatus,
                    onTap: onShareTap
                )

                SettingsDivider()
            }

            if showsVisibleMeasurementsRow {
                SettingsNavigationRow(
                    title: RuuviLocalization.visibleMeasurements,
                    value: visibleMeasurementsValue ?? RuuviLocalization.na,
                    onTap: onVisibleMeasurementsTap
                )

                SettingsDivider()
            }

            if showsLedBrightnessRow {
                SettingsNavigationRow(
                    title: RuuviLocalization.ledBrightnessControl,
                    value: ledBrightnessValue ?? RuuviLocalization.na,
                    onTap: onLedBrightnessTap
                )

                SettingsDivider()
            }

            if isNotesEditable {
                CardsSettingsSettingsValueRow(
                    title: notesTitle,
                    value: "",
                    trailing: {
                        RuuviAsset.editPen.swiftUIImage
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(RuuviColor.tintColor.swiftUIColor)
                    },
                    onTap: onNotesTap
                )
            } else {
                CardsSettingsSettingsValueRow(
                    title: notesTitle,
                    value: ""
                )
            }

            if hasNotes {
                SettingsDivider()

                CardsSettingsNotesPreview(
                    notes: notes
                )
            }
        }
    }
}

private struct CardsSettingsNotesPreview: View {
    let notes: String
    @State private var isExpanded = false

    private struct Constants {
        static let previewCharacterLimit: Int = 200
        static let verticalSpacing: CGFloat = 8
        static let rowPadding: CGFloat = 12
        static let animationDuration: Double = 0.2
    }

    private var hasNotes: Bool {
        !notes.isEmpty
    }

    private var shouldTruncate: Bool {
        notes.count > Constants.previewCharacterLimit
    }

    private var notePreview: String {
        if shouldTruncate, !isExpanded {
            return String(notes.prefix(Constants.previewCharacterLimit)) + "…"
        }
        return notes
    }

    private var displayText: String {
        hasNotes ? notePreview : RuuviLocalization.na
    }

    private var chevronName: String {
        isExpanded ? "chevron.up" : "chevron.down"
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: Constants.verticalSpacing
        ) {
            Text(displayText)
                .foregroundStyle(
                    hasNotes ? RuuviColor.textColor.swiftUIColor : Color.secondary
                )
                .font(.ruuviBody())
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleExpandedIfNeeded()
                }

            if shouldTruncate {
                HStack {
                    Spacer()
                    Button(action: {
                        toggleExpandedIfNeeded()
                    }, label: {
                        Image(systemName: chevronName)
                            .foregroundStyle(RuuviColor.tintColor.swiftUIColor)
                    })
                    .buttonStyle(.plain)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, Constants.rowPadding)
        .padding(.vertical, Constants.rowPadding)
        .onChange(of: notes) { _ in
            isExpanded = false
        }
    }

    private func toggleExpandedIfNeeded() {
        guard shouldTruncate else { return }
        withAnimation(
            .easeInOut(duration: Constants.animationDuration)
        ) {
            isExpanded.toggle()
        }
    }
}
