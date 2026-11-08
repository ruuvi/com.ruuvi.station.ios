import UIKit

/// Gates for iPhone Duo specific layout.
///
/// Every function returns `false` / `[]` on all iPhones and iPads that exist today, so code placed
/// behind these gates never runs there and their look & behaviour stays unchanged.
/// - `isVerticalBarActive`: UIKit documents `verticalBarEdge` as `.unspecified` on hardware and in
///   contexts where the system never places a vertical bar.
/// - `isFoldingDisplay` / `activeFolds`: only a folding display reports *division* reserved regions.
///
/// Safe to use from app extensions (no `UIApplication.shared`).
public enum RuuviDuoLayout {

    /// `true` once the app has seen a hinge (iPhone Duo). Set by the app from `UIHingeInteraction`;
    /// always `false` on iPhone and iPad.
    public private(set) static var isFoldableDevice = false

    /// Called by the app when a `UIHingeInteraction` reports a hinge.
    public static func noteHingePresent() {
        isFoldableDevice = true
    }

    /// `true` where the system lays out navigation bars, toolbars and tab bars vertically on the
    /// side (iPhone Duo outer display, inner display in landscape).
    public static func isVerticalBarActive(_ traits: UITraitCollection) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        return traits.verticalBarEdge != .unspecified
    }

    /// `true` when `view` is shown on iPhone Duo's inner folding display, fully open or partially
    /// folded. Requires `view` to be in a window; returns `false` otherwise.
    public static func isFoldingDisplay(_ view: UIView) -> Bool {
        guard #available(iOS 27.1, *), view.window != nil else { return false }
        return !view.reservedRegions(kind: .division, options: .includeInactive).isEmpty
    }

    /// Frames of the active folds in `view`'s coordinate space. Non-empty only while iPhone Duo is
    /// partially folded.
    public static func activeFolds(in view: UIView) -> [CGRect] {
        guard #available(iOS 27.1, *), view.window != nil else { return [] }
        return view.reservedRegions(kind: .division)
            .filter(\.isActive)
            .map(\.frame)
    }

    /// The traits to observe (with `registerForTraitChanges`) to learn when
    /// `isVerticalBarActive` may have changed.
    @available(iOS 27.1, *)
    public static var traitsAffectingVerticalBar: [UITrait] {
        UITraitCollection.systemTraitsAffectingVerticalBarEdge
    }
}

/// Switches between a screen's original constraints and constraints that keep its content inside
/// the horizontal safe area while iPhone Duo shows its vertical bar (the vertical bar and the
/// vertical status bar sit on a side of the display). On iPhone and iPad the vertical bar is never
/// active, so the original constraints stay active exactly as before.
///
/// Create it where the original constraints used to be activated and call `update(for:)` from
/// `viewWillLayoutSubviews()`.
public final class RuuviVerticalBarConstraintSwitch {
    private let standardConstraints: [NSLayoutConstraint]
    private let verticalBarConstraints: [NSLayoutConstraint]
    /// `true` while the vertical-bar constraints are active (never on iPhone and iPad).
    public private(set) var isVerticalBarApplied = false

    /// Activates `standard` immediately; `verticalBar` stays inactive until needed.
    public init(standard: [NSLayoutConstraint], verticalBar: [NSLayoutConstraint]) {
        standardConstraints = standard
        verticalBarConstraints = verticalBar
        NSLayoutConstraint.activate(standard)
    }

    /// Returns `true` when the active constraints changed (never on iPhone and iPad).
    @discardableResult
    public func update(for traits: UITraitCollection) -> Bool {
        let shouldApply = RuuviDuoLayout.isVerticalBarActive(traits)
        guard shouldApply != isVerticalBarApplied else { return false }
        isVerticalBarApplied = shouldApply
        NSLayoutConstraint.deactivate(shouldApply ? standardConstraints : verticalBarConstraints)
        NSLayoutConstraint.activate(shouldApply ? verticalBarConstraints : standardConstraints)
        return true
    }
}

/// Titles for iPhone Duo vertical bar items.
///
/// Uses the regular `Localizable` table, so a translation is picked up as soon as the key exists in
/// `station.localization` (`ident_ios`). Until then the English fallback is shown. The keys match
/// the existing Android / web identifiers where those exist (`back`, `history`).
public enum RuuviDuoStrings {
    public static var menu: String { string("menu", fallback: "Menu") }
    public static var search: String { string("search", fallback: "Search") }
    public static var back: String { string("back", fallback: "Back") }
    public static var measurements: String { string("measurements", fallback: "Measurements") }
    public static var history: String { string("history", fallback: "History") }
    public static var alerts: String { string("TagSettings.Label.alerts.text", fallback: "Alerts") }
    public static var settings: String { string("TagSettings.navigationItem.title", fallback: "Sensor settings") }

    private static func string(_ key: String, fallback: String) -> String {
        RuuviDuoStringsBundleToken.bundle.localizedString(forKey: key, value: fallback, table: "Localizable")
    }
}

private final class RuuviDuoStringsBundleToken {
    static let bundle: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: RuuviDuoStringsBundleToken.self)
        #endif
    }()
}
