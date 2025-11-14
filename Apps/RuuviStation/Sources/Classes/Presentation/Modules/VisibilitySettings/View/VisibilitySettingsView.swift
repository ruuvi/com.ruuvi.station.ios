import SwiftUI
import RuuviLocalization
import RuuviOntology
import UIKit

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
            VStack(alignment: .leading, spacing: 16) {
                descriptionSection
                toggleSection
                previewSection

                if !state.viewModel.useDefault {
                    customizationSection
                }
            }
            .padding(.vertical, 16)
        }
        .background(.clear)
    }

    private var descriptionSection: some View {
        Text(state.viewModel.descriptionText)
            .font(.ruuviSubheadline())
            .foregroundColor(RuuviColor.textColor.swiftUIColor)
            .padding(.horizontal, 16)
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
//                showsStatusLabel: state.showKeepConnectionStatusLabel,
                onToggle: { value in
                    onToggleUseDefault(value)
                }
            )
        }
        .padding([.horizontal, .top])
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
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
        .padding(.horizontal)

        return VStack(spacing: 12) {
            header
            visibleSection
            hiddenSection
        }
    }

    private var visibleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            VisibilitySectionHeader(
                title: RuuviLocalization.visibleMeasurements
            )

            VStack(spacing: 0) {
                ForEach(
                    Array(state.viewModel.visibleItems.enumerated()), id: \.element.id
                ) { index, item in
                    VisibilityMeasurementRow(
                        title: item.title,
                        actionImage: Image(systemName: "xmark"),
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
                VStack(alignment: .leading, spacing: 8) {
                    VisibilitySectionHeader(
                        title: RuuviLocalization.hideMeasurements
                    )

                    VStack(spacing: 0) {
                        ForEach(
                            Array(state.viewModel.hiddenItems.enumerated()), id: \.element.id
                        ) { index, item in
                            VisibilityMeasurementRow(
                                title: item.title,
                                actionImage: Image(systemName: "plus"),
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

private struct VisibilityMeasurementRow: View {
    let title: String
    let actionImage: Image
    let actionTint: Color
    let showReorder: Bool
    let actionAccessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.ruuviBody())
                .foregroundStyle(RuuviColor.textColor.swiftUIColor)
            Spacer()
            if showReorder {
                Image(systemName: "arrow.up.and.down")
                    .foregroundStyle(actionTint.opacity(0.6))
            }
            Button(action: action) {
                actionImage
                    .resizable()
                    .frame(width: 16, height: 16)
                    .foregroundStyle(actionTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionAccessibilityLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

private struct DashboardPreviewCard: View {
    let preview: VisibilitySettingsPreviewViewModel
    @State private var cardHeight: CGFloat = 220

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            DashboardCellPreviewRepresentable(
                snapshot: preview.snapshot,
                dashboardType: preview.dashboardType
            )
            .frame(width: width, height: cardHeight)
            .onAppear {
                updateCardHeight(
                    for: width,
                    snapshot: preview.snapshot,
                    dashboardType: preview.dashboardType
                )
            }
            .onChange(of: width) { newWidth in
                updateCardHeight(
                    for: newWidth,
                    snapshot: preview.snapshot,
                    dashboardType: preview.dashboardType
                )
            }
            .onChange(of: preview.snapshot) { newSnapshot in
                updateCardHeight(
                    for: width,
                    snapshot: newSnapshot,
                    dashboardType: preview.dashboardType
                )
            }
            .onChange(of: preview.dashboardType) { _ in
                updateCardHeight(
                    for: width,
                    snapshot: preview.snapshot,
                    dashboardType: preview.dashboardType
                )
            }
        }
        .frame(height: cardHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(RuuviColor.dashboardIndicator.swiftUIColor.opacity(0.08))
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
    }

    private func height(
        for width: CGFloat,
        snapshot: RuuviTagCardSnapshot,
        dashboardType: DashboardType
    ) -> CGFloat {
        guard width > 0 else {
            return cardHeight
        }
        return DashboardCell.calculateHeight(
            for: snapshot,
            width: width,
            dashboardType: dashboardType,
            numberOfColumns: 1
        )
    }

    private func updateCardHeight(
        for width: CGFloat,
        snapshot: RuuviTagCardSnapshot,
        dashboardType: DashboardType
    ) {
        let newHeight = height(
            for: width,
            snapshot: snapshot,
            dashboardType: dashboardType
        )
        guard newHeight != cardHeight else { return }
        cardHeight = newHeight
    }
}

private struct PreviewPlaceholderView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor.opacity(0.6))
            .frame(height: 140)
            .overlay(
                Text(RuuviLocalization.na)
                    .font(.ruuviSubheadline())
                    .foregroundStyle(RuuviColor.textColor.swiftUIColor.opacity(0.6))
            )
    }
}

private struct DashboardCellPreviewRepresentable: UIViewRepresentable {
    let snapshot: RuuviTagCardSnapshot
    let dashboardType: DashboardType

    func makeUIView(context: Context) -> DashboardCellPreviewContainerView {
        let view = DashboardCellPreviewContainerView()
        view.configure(with: snapshot, dashboardType: dashboardType)
        return view
    }

    func updateUIView(_ uiView: DashboardCellPreviewContainerView, context: Context) {
        uiView.configure(with: snapshot, dashboardType: dashboardType)
    }
}

private final class DashboardCellPreviewContainerView: UIView {
    private let cell = DashboardCell(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.isUserInteractionEnabled = false
        cell.contentView.isUserInteractionEnabled = false
        addSubview(cell)
        NSLayoutConstraint.activate([
            cell.topAnchor.constraint(equalTo: topAnchor),
            cell.leadingAnchor.constraint(equalTo: leadingAnchor),
            cell.trailingAnchor.constraint(equalTo: trailingAnchor),
            cell.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with snapshot: RuuviTagCardSnapshot, dashboardType: DashboardType) {
        cell.prepareForReuse()
        cell.configure(with: snapshot, dashboardType: dashboardType)
    }

    deinit {
        cell.prepareForReuse()
    }
}

private struct VisibilitySectionHeader: View {
    let title: String

    var body: some View {
        VStack {
            Text(title)
                .ruuviButtonLarge()
                .foregroundStyle(
                    RuuviColor.dashboardIndicator.swiftUIColor
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal)
        }
        .background(
            RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor
        )
        .contentShape(Rectangle())
    }
}

private struct VisibilityDropDelegate: DropDelegate {
    let targetItem: VisibilitySettingsItemViewModel
    @Binding var draggedItem: VisibilitySettingsItemViewModel?
    let visibleItemsProvider: () -> [VisibilitySettingsItemViewModel]
    let onMove: (Int, Int) -> Void
    let onMoveFinished: () -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedItem, draggedItem != targetItem else { return }
        let items = visibleItemsProvider()
        guard
            let fromIndex = items.firstIndex(of: draggedItem),
            let toIndex = items.firstIndex(of: targetItem),
            fromIndex != toIndex
        else { return }
        withAnimation(.easeInOut) {
            onMove(fromIndex, toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        onMoveFinished()
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}
