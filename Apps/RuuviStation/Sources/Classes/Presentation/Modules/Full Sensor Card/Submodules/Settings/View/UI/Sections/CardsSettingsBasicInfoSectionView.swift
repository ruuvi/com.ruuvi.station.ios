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
                    title: RuuviLocalization.notes,
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
                    title: RuuviLocalization.notes,
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
    @State private var fullTextHeight: CGFloat = 0
    @State private var collapsedTextHeight: CGFloat = 0

    private struct Constants {
        static let collapsedLineLimit: Int = 4
        static let verticalSpacing: CGFloat = 8
        static let rowPadding: CGFloat = 12
        static let animationDuration: Double = 0.2
    }

    private var hasNotes: Bool {
        !notes.isEmpty
    }

    private var displayText: String {
        hasNotes ? notes : RuuviLocalization.na
    }

    private var shouldTruncate: Bool {
        hasNotes && fullTextHeight > (collapsedTextHeight + 1)
    }

    private var lineLimit: Int? {
        isExpanded ? nil : Constants.collapsedLineLimit
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
                .font(.ruuviBodySmall())
                .lineLimit(lineLimit)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Text(displayText)
                        .font(.ruuviBodySmall())
                        .lineLimit(Constants.collapsedLineLimit)
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .readCollapsedHeight { height in
                            collapsedTextHeight = height
                        }
                )
                .background(
                    Text(displayText)
                        .font(.ruuviBodySmall())
                        .fixedSize(horizontal: false, vertical: true)
                        .hidden()
                        .readFullHeight { height in
                            fullTextHeight = height
                        }
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
            fullTextHeight = 0
            collapsedTextHeight = 0
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

private struct NotesPreviewCollapsedHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct NotesPreviewFullHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readCollapsedHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NotesPreviewCollapsedHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(
            NotesPreviewCollapsedHeightPreferenceKey.self,
            perform: onChange
        )
    }

    func readFullHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: NotesPreviewFullHeightPreferenceKey.self,
                    value: proxy.size.height
                )
            }
        )
        .onPreferenceChange(
            NotesPreviewFullHeightPreferenceKey.self,
            perform: onChange
        )
    }
}
