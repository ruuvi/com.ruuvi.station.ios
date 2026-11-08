import RuuviLocalization
import UIKit

extension UIView {
    /// `fillSuperview(padding:)`, except while iPhone Duo shows its vertical bar on a side of the
    /// display: then the horizontal edges follow the superview's safe area, so the content doesn't run
    /// under the bar. On iPhone and iPad this is exactly `fillSuperview(padding:)`.
    ///
    /// For views created per call (e.g. table section footers); pair it with
    /// `UITableViewController.reloadWhenVerticalBarChanges()`.
    func fillSuperviewAvoidingVerticalBar(padding: UIEdgeInsets, traits: UITraitCollection) {
        guard RuuviDuoLayout.isVerticalBarActive(traits), let superview else {
            fillSuperview(padding: padding)
            return
        }
        anchor(
            top: superview.topAnchor,
            leading: superview.safeAreaLayoutGuide.leadingAnchor,
            bottom: superview.bottomAnchor,
            trailing: superview.safeAreaLayoutGuide.trailingAnchor,
            padding: padding
        )
    }
}

extension UITableViewController {
    /// iPhone Duo: reloads the table when the vertical bar appears or disappears (device opened,
    /// closed or rotated) so views built with `fillSuperviewAvoidingVerticalBar` are rebuilt.
    /// Never reloads on iPhone and iPad, where the vertical bar is never active.
    func reloadWhenVerticalBarChanges() {
        guard #available(iOS 27.1, *) else { return }
        registerForTraitChanges(RuuviDuoLayout.traitsAffectingVerticalBar) {
            (controller: UITableViewController, previousTraits: UITraitCollection) in
            let wasActive = RuuviDuoLayout.isVerticalBarActive(previousTraits)
            let isActive = RuuviDuoLayout.isVerticalBarActive(controller.traitCollection)
            if wasActive != isActive {
                controller.tableView.reloadData()
            }
        }
    }
}
