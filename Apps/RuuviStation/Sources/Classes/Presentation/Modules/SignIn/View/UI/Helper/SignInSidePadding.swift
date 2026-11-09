import RuuviLocalization
import UIKit

extension UIViewController {
    /// The layout class the sign-in pages use for their side paddings: the class of the window the
    /// screen is shown in. A sheet's own horizontal size class can be compact on a full-screen iPad,
    /// so it is not used. Before the sheet is in its window (its first layout passes happen while it
    /// is being presented), the presenting screen's window is used, so the pages are laid out with
    /// the right paddings from the start, as before.
    var signInLayoutClass: RuuviLayoutClass {
        if let window = viewIfLoaded?.window ?? presentingViewController?.viewIfLoaded?.window {
            return window.traitCollection.ruuviLayoutClass
        }
        return traitCollection.ruuviLayoutClass
    }
}

extension AnchoredConstraints {
    /// Sets the leading and trailing padding of a sign-in page element: today's iPad value for the
    /// `.regular` layout class, the iPhone value otherwise. Does nothing while it stays the same.
    ///
    /// When the padding changes after the page was laid out (a window resized across the regular
    /// size class), a wrapped label whose width follows it must be measured again, or it keeps the
    /// height of its old width and cuts its text short. Pass such labels as `labels`.
    func setSignInSidePadding(_ padding: CGFloat, remeasuring labels: [UILabel] = []) {
        guard leading?.constant != padding || trailing?.constant != -padding else { return }
        leading?.constant = padding
        trailing?.constant = -padding
        labels.forEach { label in
            label.invalidateIntrinsicContentSize()
            label.superview?.setNeedsLayout()
        }
    }
}
