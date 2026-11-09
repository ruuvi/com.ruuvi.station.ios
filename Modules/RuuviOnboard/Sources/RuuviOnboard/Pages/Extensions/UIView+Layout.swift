import UIKit

/// This is for adding constraint to declared views
/// It helps to reduce a lot of redundant code to set constraint for all views

extension UIView {
    @discardableResult
    func anchor(
        top: NSLayoutYAxisAnchor?,
        leading: NSLayoutXAxisAnchor?,
        bottom: NSLayoutYAxisAnchor?,
        trailing: NSLayoutXAxisAnchor?,
        padding: UIEdgeInsets = .zero,
        size: CGSize = .zero
    ) -> AnchoredConstraints {
        translatesAutoresizingMaskIntoConstraints = false
        var anchoredConstraints = AnchoredConstraints()

        if let top {
            anchoredConstraints.top = topAnchor.constraint(
                equalTo: top,
                constant: padding.top
            )
        }

        if let leading {
            anchoredConstraints.leading = leadingAnchor.constraint(
                equalTo: leading,
                constant: padding.left
            )
        }

        if let bottom {
            anchoredConstraints.bottom = bottomAnchor.constraint(
                equalTo: bottom,
                constant: -padding.bottom
            )
        }

        if let trailing {
            anchoredConstraints.trailing = trailingAnchor.constraint(
                equalTo: trailing,
                constant: -padding.right
            )
        }

        if size.width != 0 {
            anchoredConstraints.width = widthAnchor.constraint(equalToConstant: size.width)
        }

        if size.height != 0 {
            anchoredConstraints.height = heightAnchor.constraint(equalToConstant: size.height)
        }

        [
            anchoredConstraints.top,
            anchoredConstraints.leading,
            anchoredConstraints.bottom,
            anchoredConstraints.trailing,
            anchoredConstraints.width,
            anchoredConstraints.height,
        ].forEach { $0?.isActive = true }

        return anchoredConstraints
    }

    @discardableResult
    func anchorLeading(
        top: NSLayoutYAxisAnchor?,
        leading: NSLayoutXAxisAnchor?,
        bottom: NSLayoutYAxisAnchor?,
        trailing: NSLayoutXAxisAnchor?,
        padding: UIEdgeInsets = .zero,
        size: CGSize = .zero
    ) -> AnchoredConstraints {
        translatesAutoresizingMaskIntoConstraints = false
        var anchoredConstraints = AnchoredConstraints()

        if let top {
            anchoredConstraints.top = topAnchor.constraint(equalTo: top, constant: padding.top)
        }

        if let leading {
            anchoredConstraints.leading =
                leadingAnchor.constraint(
                    greaterThanOrEqualTo: leading,
                    constant: padding.left
                )
        }

        if let bottom {
            anchoredConstraints.bottom =
                bottomAnchor.constraint(
                    equalTo: bottom,
                    constant: -padding.bottom
                )
        }

        if let trailing {
            anchoredConstraints.trailing =
                trailingAnchor.constraint(
                    lessThanOrEqualTo: trailing,
                    constant: -padding.right
                )
        }

        if size.width != 0 {
            anchoredConstraints.width = widthAnchor.constraint(equalToConstant: size.width)
        }

        if size.height != 0 {
            anchoredConstraints.height = heightAnchor.constraint(equalToConstant: size.height)
        }

        [
            anchoredConstraints.top,
            anchoredConstraints.leading,
            anchoredConstraints.bottom,
            anchoredConstraints.trailing,
            anchoredConstraints.width,
            anchoredConstraints.height,
        ].forEach { $0?.isActive = true }

        return anchoredConstraints
    }

    func fillSuperview(padding: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        if let superviewTopAnchor = superview?.topAnchor {
            topAnchor.constraint(equalTo: superviewTopAnchor, constant: padding.top).isActive = true
        }

        if let superviewBottomAnchor = superview?.bottomAnchor {
            bottomAnchor.constraint(equalTo: superviewBottomAnchor, constant: -padding.bottom).isActive = true
        }

        if let superviewLeadingAnchor = superview?.leadingAnchor {
            leadingAnchor.constraint(equalTo: superviewLeadingAnchor, constant: padding.left).isActive = true
        }

        if let superviewTrailingAnchor = superview?.trailingAnchor {
            trailingAnchor.constraint(equalTo: superviewTrailingAnchor, constant: -padding.right).isActive = true
        }
    }

    func fillSuperviewToSafeArea(padding: UIEdgeInsets = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        if let superviewTopAnchor = superview?.safeTopAnchor {
            topAnchor.constraint(equalTo: superviewTopAnchor, constant: padding.top).isActive = true
        }

        if let superviewBottomAnchor = superview?.safeBottomAnchor {
            bottomAnchor.constraint(equalTo: superviewBottomAnchor, constant: -padding.bottom).isActive = true
        }

        if let superviewLeadingAnchor = superview?.safeLeadingAnchor {
            leadingAnchor.constraint(equalTo: superviewLeadingAnchor, constant: padding.left).isActive = true
        }

        if let superviewTrailingAnchor = superview?.safeTrailingAnchor {
            trailingAnchor.constraint(equalTo: superviewTrailingAnchor, constant: -padding.right).isActive = true
        }
    }

    func centerInSuperview(size: CGSize = .zero) {
        translatesAutoresizingMaskIntoConstraints = false
        if let superviewCenterXAnchor = superview?.centerXAnchor {
            centerXAnchor.constraint(equalTo: superviewCenterXAnchor).isActive = true
        }

        if let superviewCenterYAnchor = superview?.centerYAnchor {
            centerYAnchor.constraint(equalTo: superviewCenterYAnchor).isActive = true
        }

        if size.width != 0 {
            widthAnchor.constraint(equalToConstant: size.width).isActive = true
        }

        if size.height != 0 {
            heightAnchor.constraint(equalToConstant: size.height).isActive = true
        }
    }

    func centerXInSuperview() {
        translatesAutoresizingMaskIntoConstraints = false
        if let superViewCenterXAnchor = superview?.centerXAnchor {
            centerXAnchor.constraint(equalTo: superViewCenterXAnchor).isActive = true
        }
    }

    func centerYInSuperview() {
        translatesAutoresizingMaskIntoConstraints = false
        if let centerY = superview?.centerYAnchor {
            centerYAnchor.constraint(equalTo: centerY).isActive = true
        }
    }

    func constrainWidth(constant: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: constant).isActive = true
    }

    func constrainHeight(constant: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: constant).isActive = true
    }

    func size(width: CGFloat, height: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(equalToConstant: height).isActive = true
        widthAnchor.constraint(equalToConstant: width).isActive = true
    }

    func widthLessThanOrEqualTo(constant: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(lessThanOrEqualToConstant: constant).isActive = true
    }

    func widthGreaterThanOrEqualTo(constant: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(greaterThanOrEqualToConstant: constant).isActive = true
    }

    func heightGreaterThanOrEqualTo(constant: CGFloat) {
        translatesAutoresizingMaskIntoConstraints = false
        heightAnchor.constraint(greaterThanOrEqualToConstant: constant).isActive = true
    }

    func match(view: UIView) {
        translatesAutoresizingMaskIntoConstraints = false
        topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        leadingAnchor.constraint(equalTo: view.leadingAnchor).isActive = true
        trailingAnchor.constraint(equalTo: view.trailingAnchor).isActive = true
    }
}

struct AnchoredConstraints {
    var top,
        leading,
        bottom,
        trailing,
        width,
        height: NSLayoutConstraint?
}

extension UIView {
    var safeTopAnchor: NSLayoutYAxisAnchor {
        return self.safeAreaLayoutGuide.topAnchor
    }

    var safeLeadingAnchor: NSLayoutXAxisAnchor {
        return self.safeAreaLayoutGuide.leadingAnchor
    }

    var safeTrailingAnchor: NSLayoutXAxisAnchor {
        return self.safeAreaLayoutGuide.trailingAnchor
    }

    var safeBottomAnchor: NSLayoutYAxisAnchor {
        return self.safeAreaLayoutGuide.bottomAnchor
    }
}

// MARK: - Scrolling page

extension UIView {
    /// Adds a vertical scroll view to this view and returns it with `container`, the view to lay an
    /// onboarding page out in (a clear, clipping `UIView(color:)`, like the pages used before).
    ///
    /// While the page content fits, `container` is exactly as tall as the scroll view, so nothing
    /// scrolls or bounces and the page looks as it does without the scroll view. When the page is
    /// shorter than its content (a short window), `container` grows to fit the content and the page
    /// scrolls, so no text or button is cut off.
    ///
    /// Priorities: `container` keeps the scroll view's height at priority 500. Content that should
    /// give way before the page scrolls (an image) must resist compression below that (e.g.
    /// `.defaultLow`); text and buttons keep the default 750, so they are never compressed. A view
    /// that only fills the remaining space (no intrinsic height) needs a `>= 0` height so the page
    /// grows instead of that view's height going negative.
    ///
    /// The scroll view does not adjust its insets: the content lays out against its own safe area,
    /// as the pages already do inside the paging collection view.
    ///
    /// - Parameter bottom: Where the scroll view ends; the bottom of this view by default.
    func addScrollingPage(
        bottom: NSLayoutYAxisAnchor? = nil
    ) -> (scrollView: UIScrollView, container: UIView) {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceVertical = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)
        scrollView.anchor(
            top: topAnchor,
            leading: leadingAnchor,
            bottom: bottom ?? bottomAnchor,
            trailing: trailingAnchor
        )

        let container = UIView(color: .clear)
        scrollView.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        let fillsPage = container.heightAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.heightAnchor
        )
        fillsPage.priority = UILayoutPriority(500)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            container.heightAnchor.constraint(
                greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor
            ),
            fillsPage,
        ])
        return (scrollView, container)
    }
}
