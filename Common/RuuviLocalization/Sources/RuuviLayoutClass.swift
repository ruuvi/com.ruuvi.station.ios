import SwiftUI
import UIKit

/// The three layouts the app has. They are picked from the size classes of the view's own trait
/// collection only, never from the device type or the interface/device orientation, so a layout
/// always follows the space it is shown in: a full-screen iPhone or iPad, a resized iPad window, or
/// either iPhone Duo display.
///
/// | Horizontal | Vertical  | Layout           | Examples                                        |
/// |------------|-----------|------------------|-------------------------------------------------|
/// | regular    | regular   | `.regular`       | iPad, large iPad windows, iPhone Duo inner      |
/// | any        | compact   | `.compactHeight` | iPhone landscape (Pro Max too), short windows   |
/// | otherwise  | otherwise | `.compactWidth`  | iPhone portrait, narrow iPad windows            |
///
/// Both axes are checked for `.regular`, so iPhone Pro Max in landscape (regular width, compact
/// height) keeps the iPhone landscape layout. Size classes are `.unspecified` until a view is in a
/// window; that falls into `.compactWidth`, so read the class again once the view is in a window.
///
/// Content shown in a sheet uses `UIView.ruuviWindowLayoutClass` instead: on iPad, UIKit gives a
/// floating sheet no wider than a form sheet a compact width, even on a full-screen iPad.
public enum RuuviLayoutClass: Equatable, Sendable {
    /// Today's iPad layout.
    case regular
    /// Today's iPhone portrait layout.
    case compactWidth
    /// Today's iPhone landscape layout.
    case compactHeight

    public init(_ traits: UITraitCollection) {
        self.init(horizontal: traits.horizontalSizeClass, vertical: traits.verticalSizeClass)
    }

    public init(horizontal: UIUserInterfaceSizeClass, vertical: UIUserInterfaceSizeClass) {
        if vertical == .compact {
            self = .compactHeight
        } else if horizontal == .regular, vertical == .regular {
            self = .regular
        } else {
            self = .compactWidth
        }
    }

    /// For SwiftUI: pass `@Environment(\.horizontalSizeClass)` and `@Environment(\.verticalSizeClass)`.
    public init(horizontal: UserInterfaceSizeClass?, vertical: UserInterfaceSizeClass?) {
        self.init(horizontal: UIUserInterfaceSizeClass(horizontal), vertical: UIUserInterfaceSizeClass(vertical))
    }

    public var isRegular: Bool { self == .regular }
    public var isCompactHeight: Bool { self == .compactHeight }

    /// The traits to observe with `registerForTraitChanges` (iOS 17+) to learn when the layout class
    /// may have changed. On iOS 16 use `traitCollectionDidChange(_:)`.
    @available(iOS 17.0, *)
    public static var traitsAffectingLayoutClass: [UITrait] {
        [UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]
    }
}

public extension UITraitCollection {
    /// The app layout for these traits. See `RuuviLayoutClass`.
    var ruuviLayoutClass: RuuviLayoutClass { RuuviLayoutClass(self) }
}

/// Picks how many equal columns a grid shows in the width it actually has (the window, not the
/// screen or the orientation). With the bounds each grid passes in, today's column counts on
/// full-screen iPhones and iPads come out unchanged, and any other width (a resized iPad window, an
/// iPhone Duo display) gets the count that fits.
public enum RuuviGridFit {
    /// - Parameters:
    ///   - width: The width the grid lays out in, including its padding.
    ///   - counts: The column counts the grid may use.
    ///   - spacing: The gap between two columns.
    ///   - padding: The total horizontal padding (leading plus trailing) for a column count.
    ///   - minimumColumnWidth: Columns are never narrower than this, unless even the smallest count
    ///     would make them so.
    ///   - maximumColumnWidth: The grid uses the fewest columns that are no wider than this.
    /// - Returns: The smallest of `counts` whose columns are at most `maximumColumnWidth` wide (the
    ///   largest count if none is). If that makes them narrower than `minimumColumnWidth`, the
    ///   largest smaller count whose columns are still at least that wide, or the smallest count.
    public static func columns(
        in width: CGFloat,
        counts: [Int],
        spacing: CGFloat = 0,
        padding: (Int) -> CGFloat = { _ in 0 },
        minimumColumnWidth: CGFloat = 0,
        maximumColumnWidth: CGFloat
    ) -> Int {
        let sorted = Set(counts.filter { $0 > 0 }).sorted()
        guard let smallest = sorted.first, let largest = sorted.last else { return 1 }
        guard width > 0 else { return smallest }

        func columnWidth(_ count: Int) -> CGFloat {
            Self.columnWidth(in: width, columns: count, spacing: spacing, padding: padding(count))
        }

        let fitting = sorted.first { columnWidth($0) <= maximumColumnWidth } ?? largest
        if columnWidth(fitting) >= minimumColumnWidth {
            return fitting
        }
        return sorted.last { $0 < fitting && columnWidth($0) >= minimumColumnWidth } ?? smallest
    }

    /// The width of one column when `columns` columns share `width`.
    public static func columnWidth(
        in width: CGFloat,
        columns: Int,
        spacing: CGFloat = 0,
        padding: CGFloat = 0
    ) -> CGFloat {
        let count = CGFloat(max(columns, 1))
        return (width - padding - spacing * (count - 1)) / count
    }
}

public extension UIView {
    /// The layout class of the window this view is in (the view's own until it has a window). Use it
    /// for content shown in a sheet, whose own horizontal size class can be compact on a full-screen
    /// iPad (see `RuuviLayoutClass`).
    var ruuviWindowLayoutClass: RuuviLayoutClass {
        (window?.traitCollection ?? traitCollection).ruuviLayoutClass
    }

    /// How far a custom header that replaces the navigation bar must move its leading edge in from
    /// the plain safe area to stay clear of the window controls (close, minimize, resize) that iPadOS
    /// 26 and later shows in the top-leading corner of a window that does not fill the screen.
    ///
    /// Exactly 0 on iPhone, on a full-screen iPad, on iPhone Duo and before iOS 26, so those layouts
    /// stay as they are. (The corner-adapted safe area alone can't be used for this: it also keeps
    /// clear of the rounded display corners, which would move the header on every iPhone and iPad.)
    /// Read it in a layout pass; it changes when the window is resized or moved to another screen.
    var ruuviWindowControlsLeadingInset: CGFloat {
        guard #available(iOS 26.0, *), let windowScene = window?.windowScene else { return 0 }
        let sceneSize = windowScene.effectiveGeometry.coordinateSpace.bounds.size
        let screenSize = windowScene.screen.bounds.size
        let fillsScreen = (sceneSize.width >= screenSize.width && sceneSize.height >= screenSize.height)
            || (sceneSize.width >= screenSize.height && sceneSize.height >= screenSize.width)
        guard !fillsScreen else { return 0 }
        let cornerAdapted = directionalEdgeInsets(for: .safeArea(cornerAdaptation: .horizontal)).leading
        let plain = directionalEdgeInsets(for: .safeArea()).leading
        return max(0, (cornerAdapted - plain).rounded(.up))
    }
}

/// Keeps a custom header's leading constraint clear of the iPadOS window controls: its constant is
/// `baseConstant + view.ruuviWindowControlsLeadingInset`. Create it with the header's leading
/// constraint, pinned to the plain safe area as before, and call `update()` from
/// `viewDidLayoutSubviews()`. On iPhone, full-screen iPad and iPhone Duo the constant stays
/// `baseConstant`.
public final class RuuviWindowControlsInsetUpdater {
    private weak var view: UIView?
    private weak var constraint: NSLayoutConstraint?
    /// The constant without window controls (for example a vertical-bar inset on iPhone Duo).
    public var baseConstant: CGFloat {
        didSet { update() }
    }

    /// - Parameters:
    ///   - constraint: The header's leading constraint; its current constant becomes `baseConstant`.
    ///   - view: The view controller's root view (the window controls are measured on it).
    public init(constraint: NSLayoutConstraint, in view: UIView) {
        self.constraint = constraint
        self.view = view
        baseConstant = constraint.constant
    }

    /// Applies the current inset. Cheap and idempotent: it only writes the constant when it changed.
    public func update() {
        guard let view, let constraint else { return }
        let constant = baseConstant + view.ruuviWindowControlsLeadingInset
        if constraint.constant != constant {
            constraint.constant = constant
        }
    }
}
