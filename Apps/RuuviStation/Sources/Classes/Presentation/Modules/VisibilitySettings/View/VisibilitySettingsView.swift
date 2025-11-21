import SwiftUI
import RuuviLocalization
import RuuviOntology
import UIKit

private struct Constants {
    static let stackSpacing: CGFloat = 16
    static let bodyVerticalPadding: CGFloat = 16
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 16
    static let previewSpacing: CGFloat = 8
    static let sectionSpacing: CGFloat = 12
    static let sectionHeaderSpacing: CGFloat = 8
    static let hideActionSymbolName = "xmark"
    static let showActionSymbolName = "plus"
}

struct VisibilitySettingsView: View {
    @ObservedObject var state: VisibilitySettingsViewState
    let onToggleUseDefault: (Bool) -> Void
    let onHideVisible: (Int) -> Void
    let onShowHidden: (Int) -> Void
    let onMoveVisible: (Int, Int) -> Void
    let onFinishVisibleMove: () -> Void

    @State private var draggedItem: VisibilitySettingsItemViewModel?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Constants.stackSpacing) {
                descriptionSection
                toggleSection
                previewSection

                if !state.viewModel.useDefault {
                    customizationSection
                }
            }
            .padding(.vertical, Constants.bodyVerticalPadding)
        }
        .background(.clear)
    }

    private var descriptionSection: some View {
        Text(state.viewModel.descriptionText)
            .font(.ruuviSubheadline())
            .foregroundColor(RuuviColor.textColor.swiftUIColor)
            .padding(.horizontal, Constants.horizontalPadding)
    }

    private var toggleSection: some View {
        let binding = Binding(
            get: { state.viewModel.useDefault },
            set: { value in
                onToggleUseDefault(value)
            }
        )

        return HStack {
            Text(RuuviLocalization.visibleMeasurementsUseDefault)
                .font(.ruuviHeadline())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
            Spacer()
            RuuviSwitchRepresentable(
                isOn: binding,
                isEnabled: true,
                showsStatusLabel: true,
                onToggle: { value in
                    onToggleUseDefault(value)
                }
            )
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.top, Constants.topPadding)
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: Constants.previewSpacing) {
            Text(RuuviLocalization.preview)
                .font(.ruuviHeadline())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
            if let preview = state.viewModel.preview {
                DashboardPreviewCard(preview: preview)
            } else {
                PreviewPlaceholderView()
            }
        }
        .padding(.horizontal)
    }

    private var customizationSection: some View {
        let header = VStack(spacing: 8) {
            Text(RuuviLocalization.customisationSettings)
                .font(.ruuviHeadline())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(RuuviLocalization.customisationSettingsDescription)
                .font(.ruuviSubheadline())
                .foregroundColor(RuuviColor.textColor.swiftUIColor)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Constants.horizontalPadding)

        return VStack(spacing: Constants.sectionSpacing) {
            header
            visibleSection
            hiddenSection
        }
    }

    private var visibleSection: some View {
        VStack(alignment: .leading, spacing: Constants.sectionHeaderSpacing) {
            VisibilitySectionHeader(
                title: RuuviLocalization.visibleMeasurements
            )

            VStack(spacing: 0) {
                ForEach(
                    Array(state.viewModel.visibleItems.enumerated()), id: \.element.id
                ) { index, item in
                    VisibilityMeasurementRow(
                        title: item.title,
                        actionImage: Image(systemName: Constants.hideActionSymbolName),
                        actionTint: RuuviColor.tintColor.swiftUIColor,
                        showReorder: true,
                        actionAccessibilityLabel: RuuviLocalization.remove,
                        action: {
                            withAnimation(.easeInOut) {
                                onHideVisible(index)
                            }
                        }
                    )
                    .onDrag {
                        draggedItem = item
                        return NSItemProvider(object: item.title as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: VisibilityDropDelegate(
                            targetItem: item,
                            draggedItem: $draggedItem,
                            visibleItemsProvider: { state.viewModel.visibleItems },
                            onMove: onMoveVisible,
                            onMoveFinished: onFinishVisibleMove
                        )
                    )
                }
            }
        }
    }

    private var hiddenSection: some View {
        Group {
            if !state.viewModel.hiddenItems.isEmpty {
                VStack(alignment: .leading, spacing: Constants.sectionHeaderSpacing) {
                    VisibilitySectionHeader(
                        title: RuuviLocalization.hideMeasurements
                    )

                    VStack(spacing: 0) {
                        ForEach(
                            Array(state.viewModel.hiddenItems.enumerated()), id: \.element.id
                        ) { index, item in
                            VisibilityMeasurementRow(
                                title: item.title,
                                actionImage: Image(systemName: Constants.showActionSymbolName),
                                actionTint: RuuviColor.tintColor.swiftUIColor,
                                showReorder: false,
                                actionAccessibilityLabel: RuuviLocalization.addSensor,
                                action: {
                                    withAnimation(.easeInOut) {
                                        onShowHidden(index)
                                    }
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}
