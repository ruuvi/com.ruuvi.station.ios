import UIKit

class DashboardContextMenuButton: UIButton {

    var onMenuPresent: (() -> Void)?
    var onMenuDismiss: (() -> Void)?

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(
            interaction,
            willDisplayMenuFor: configuration,
            animator: animator
        )
        onMenuPresent?()
    }

    override func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        super.contextMenuInteraction(
            interaction,
            willEndFor: configuration,
            animator: animator
        )
        onMenuDismiss?()
    }
}
