import SwiftUI
import RuuviLocalization

private struct Constants {
    static let rowSpacing: CGFloat = 12
    static let actionIconSize: CGFloat = 16
    static let rowHorizontalPadding: CGFloat = 16
    static let rowVerticalPadding: CGFloat = 12
    static let reorderIconOpacity: Double = 0.6
    static let reorderSymbolName = "arrow.up.and.down"
    static let headerVerticalPadding: CGFloat = 12
    static let headerHorizontalPadding: CGFloat = 16
}

struct VisibilityMeasurementRow: View {
    let title: String
    let actionImage: Image
    let actionTint: Color
    let showReorder: Bool
    let actionAccessibilityLabel: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: Constants.rowSpacing) {
            Text(title)
                .font(.ruuviBody())
                .foregroundStyle(RuuviColor.textColor.swiftUIColor)
            Spacer()
            if showReorder {
                Image(systemName: Constants.reorderSymbolName)
                    .foregroundStyle(actionTint.opacity(Constants.reorderIconOpacity))
            }
            Button(action: action) {
                actionImage
                    .resizable()
                    .frame(width: Constants.actionIconSize, height: Constants.actionIconSize)
                    .foregroundStyle(actionTint)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(actionAccessibilityLabel)
        }
        .padding(.horizontal, Constants.rowHorizontalPadding)
        .padding(.vertical, Constants.rowVerticalPadding)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct VisibilitySectionHeader: View {
    let title: String

    var body: some View {
        VStack {
            Text(title)
                .ruuviButtonLarge()
                .foregroundStyle(
                    RuuviColor.dashboardIndicator.swiftUIColor
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Constants.headerVerticalPadding)
                .padding(.horizontal, Constants.headerHorizontalPadding)
        }
        .background(
            RuuviColor.tagSettingsSectionHeaderColor.swiftUIColor
        )
        .contentShape(Rectangle())
    }
}

struct VisibilityDropDelegate: DropDelegate {
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
