# iPhone Duo adaptation plan: Ruuvi Station iOS

Status: implemented on `feature/iphone-duo` (see "Implementation notes" at the end) · Written 2026-11-07 against `main` @ f2c7357f7 (3.9.0)

## How to use this plan

Run the phases in order, one commit per phase. Every decision has already been made. A few steps are
marked **Verify → act**: check the condition in the iPhone Duo simulator, then apply the fix that is
written out for that case. Don't redesign anything outside this document. If something comes up that the
plan doesn't cover, stop and ask.

## The hard rule

**iPhone and iPad must look and behave exactly as they do in 3.9.0.** Three mechanisms enforce it:

1. **Duo gates.** Duo-specific code only runs when one of the signals below is present. None of them
   can occur on any existing iPhone or iPad, so the current code path keeps running there unchanged.
   - `traitCollection.verticalBarEdge != .unspecified`. The SDK header says this value is
     `.unspecified` "on devices and in contexts where the system never places a vertical bar".
   - A *division* reserved region exists (`includeInactive`). This means the app is on the inner
     folding display.
   - An *active* division region exists. This means the device is partially folded.
2. **Like-for-like refactors only.** Shared (non-gated) code changes are limited to the replacements in
   Phase 2. Each one gives the same value as the old expression on a full-screen, single-display
   device. `UIRequiresFullScreen = true` keeps the app full screen on iPad.
3. **Screenshot gate (Phase 6).** Before merging, compare iPhone and iPad screenshots pixel by pixel.

Review rule: every changed line must either appear in the Phase 2 table or sit behind a `RuuviDuoLayout`
gate.

## Facts this plan relies on (checked 2026-11-07)

| Fact | Where |
|---|---|
| Xcode 27.2 RC with the iOS 27.2 SDK and an **iPhone Duo simulator** are installed locally | `/Applications/Xcode-27.2.0-Release.Candidate.app` |
| The release CI runs on `macos-15` with `xcode-version: 'latest-stable'` | `.github/workflows/testflight.yml:50-55`, `appstore_submit_review.yml:23-28` |
| Deployment target is iOS 16, so every new API needs `#available(iOS 27.1, *)` | `project.yml:21-22` |
| `UIRequiresFullScreen = true`, multiple scenes off, iPhone orientations Portrait/LandscapeL/R | `Apps/RuuviStation/Info.plist:75,102,106` |
| `UIScreen.main` is **already deprecated since iOS 26** | SDK `UIScreen.h:57` |
| The custom-view back buttons in about 10 settings screens are only used on `#unavailable(iOS 26)`. On iOS 26+ (including Duo) the system back button is used, so these screens move to the vertical bar with no changes | e.g. `VisibilitySettingsViewController.swift:38-50` |
| Only two screens draw their own chrome on iOS 26+, with the nav bar hidden: **Dashboard** and **Full Sensor Card** | `DashboardViewController.swift:283,385-470`; `CardsBaseViewController.swift:267,336-455` |
| The root nav controller sets `navigationBar.tintColor = .clear`, so any bar item shown there must set its own `tintColor` | `Routers/AppRouter.swift:32` |
| All menus are system `UIMenu` and all alerts are `UIAlertController`, so the system moves them off the fold | — |
| `simctl` cannot set fold poses. Use the Device Hub buttons in Xcode (manual) | `xcrun simctl ui` |
| Custom bars Apple's system ignores: only the keyboard `UIToolbar`, which Apple says should stay on the keyboard | `UITextField+Extension.swift:5` |

## Out of scope (decided)

- Split View or multiple windows. Keep `UIApplicationSupportsMultipleScenes = false` and
  `UIRequiresFullScreen = true`. Apple says the Duo honors that key, though the app still resizes on
  open/close. Removing it would change iPad behaviour.
- `ArrangementView` / `UIArrangementViewController`, hinge-angle effects, the new camera APIs (the app
  only uses system pickers), `CameraCaptureAccessory`, widget changes, and redesigns for the large
  display beyond the column and layout tweaks below.

---

## Phase 0: Toolchain (no app code)

1. Move CI to Xcode 27.x. In `testflight.yml` and `appstore_submit_review.yml`:
   - Set `runs-on:` to a macOS runner image that ships Xcode 27.1 or newer (expected `macos-26`;
     confirm against GitHub's image list).
   - Pin `xcode-version: '27.2'` instead of `latest-stable`.

   Without this, release builds use an older SDK. The app then runs in compatibility mode on the Duo:
   it won't extend under the status bar and won't get vertical bars.
2. Build `main` unchanged with Xcode 27.2. Fix only new compile errors or warnings.
3. **Baseline screenshots:** capture the Phase 6 screen list on iPhone and iPad from this build. Also
   compare against the 3.9.0 behaviour on iOS 26. Any difference at this point comes from the SDK bump,
   not from Duo work. Note it and neutralize it before going on. (Building with the iOS 27 SDK is
   mandatory from April 2027 anyway.)

## Phase 1: Foundation: a single Duo helper

**New file** `Common/RuuviLocalization/Sources/RuuviDuoLayout.swift`. RuuviLocalization is the shared UI
base that the app, RuuviPresenters, RuuviFirmware and RuuviOnboard already import. Keep the file safe
for app extensions: no `UIApplication.shared`.

```swift
import UIKit

/// iPhone Duo gates. Every function returns false / [] on all existing iPhones and iPads,
/// so code behind these gates never runs there.
public enum RuuviDuoLayout {
    /// The system places bars vertically here (Duo outer display; inner display in landscape).
    public static func isVerticalBarActive(_ traits: UITraitCollection) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        return traits.verticalBarEdge != .unspecified
    }

    /// The view is on the Duo's inner folding display (fully open or partially folded).
    public static func isFoldingDisplay(_ view: UIView) -> Bool {
        guard #available(iOS 27.1, *) else { return false }
        return !view.reservedRegions(kind: .division, options: .includeInactive).isEmpty
    }

    /// Active fold frames in `view`'s coordinate space. Only non-empty while partially folded.
    public static func activeFolds(in view: UIView) -> [CGRect] {
        guard #available(iOS 27.1, *) else { return [] }
        return view.reservedRegions(kind: .division).filter(\.isActive).map(\.frame)
    }

    /// The trait set to register for when observing `isVerticalBarActive` changes.
    @available(iOS 27.1, *)
    public static var traitsAffectingVerticalBar: [UITrait] {
        UITraitCollection.systemTraitsAffectingVerticalBarEdge
    }
}
```

**Verify → act (do this first; results go in the PR description).** Add a temporary log of the three
signals in `DashboardViewController.viewDidLayoutSubviews`. Run on the iPhone Duo simulator and use
Device Hub to cycle: outer portrait, outer landscape, inner open portrait, inner open landscape,
partially folded.

- If `includeInactive` returns **no** division region while fully open, redefine `isFoldingDisplay` as
  `traitCollection.userInterfaceIdiom == .phone && horizontalSizeClass == .regular && verticalSizeClass == .regular`.
  Add a doc comment noting that this also matches resizable iPhone Mirroring.
- If a fold or unfold does **not** cause a new layout pass, add a `UIHingeInteraction` (iOS 27.1) to the
  views that use `activeFolds` (only the dialog in 4.6) and call `view.setNeedsLayout()` when
  `update.hinge?.status` changes.
- Record whether screens with a hidden nav bar get a side safe-area inset (vertical status bar). If they
  do not, the vertical-bar mode in Phase 3 is the only correct option for the Dashboard and Card screens.
  This confirms the plan.

Remove the temporary log before committing.

**Unit test.** Add a file to the existing app-hosted unit test target under `Apps/RuuviStation/Tests/Unit/`.
On the iPhone simulator, assert that `isVerticalBarActive` is false, `isFoldingDisplay` is false and
`activeFolds` is empty for a view in a window. This turns the gate guarantee into a test.

## Phase 2: Like-for-like replacements (shared code, no behaviour change)

Add an app-target helper next to `UIWindow+Orientation.swift` (which already defines `UIWindow.key`):

```swift
// Apps/RuuviStation/Sources/Extensions/Structs/RuuviAppGeometry.swift
enum RuuviAppGeometry {
    /// Drop-in for `UIScreen.main.bounds`. The app is always full screen on iPhone and iPad
    /// (UIRequiresFullScreen = true), so the window bounds equal the screen bounds there.
    /// On iPhone Duo this is the display the app is actually on.
    static func bounds(for view: UIView?) -> CGRect {
        view?.window?.bounds ?? UIWindow.key?.bounds ?? UIScreen.main.bounds
    }
    /// Drop-in for `UIScreen.main.scale` (the same screen object on single-display devices).
    static func scale(for view: UIView?) -> CGFloat {
        (view?.window ?? UIWindow.key)?.windowScene?.screen.scale ?? UIScreen.main.scale
    }
}
```

This keeps the one remaining deprecated `UIScreen.main` call in a single place, as the last-resort
fallback.

Paths are relative to `Apps/RuuviStation/Sources/Classes/Presentation/Modules/`, except those starting
with `Extensions/`, which are relative to `Apps/RuuviStation/Sources/`.

| Site | Replace | With |
|---|---|---|
| `Full Sensor Card/Submodules/Graph/CardsGraphMarkerView.swift:58` | `UIScreen.main.bounds.width` (fallback) | `RuuviAppGeometry.bounds(for: nil).width` |
| `Full Sensor Card/Submodules/Graph/CardsGraphViewController.swift:163`, `:1210` | `UIScreen.main.bounds` (fallbacks) | `RuuviAppGeometry.bounds(for: view)` |
| `Full Sensor Card/Submodules/Measurements/CardsMeasurementPageViewController.swift:54` | `UIScreen.main.bounds.height` inside `ColumnConfig.forCurrentDevice` | a new parameter `referenceBounds: CGRect`; every caller passes `RuuviAppGeometry.bounds(for: view)` |
| same file `:201` | `UIScreen.main.bounds.width` | `RuuviAppGeometry.bounds(for: view).width` |
| `Full Sensor Card/Submodules/Measurements/Details/MeasurementDetailsCoordinator.swift:60`, `:67` | `UIScreen.main.bounds.height` | `RuuviAppGeometry.bounds(for: baseViewController.view).height` (see 4.5 for the resize handling) |
| `Extensions/Classess/ScrollViewEdgeFader.swift:324` | `UIScreen.main.bounds` | `RuuviAppGeometry.bounds(for: scrollView)` |
| `Dashboard/Util/MasonryReorderableLayout.swift:153` | `UIScreen.main.scale` | `RuuviAppGeometry.scale(for: collectionView)` |
| `My Ruuvi/View/MyRuuviAccountViewController.swift:169` | `1 / UIScreen.main.scale` | `1 / RuuviAppGeometry.scale(for: view)` |
| `Extensions/Classess/NoSensorView.swift:261-262` | `UIScreen.main.traitCollection` | `(window ?? UIWindow.key)?.traitCollection ?? traitCollection` (a full-screen window has the same size classes as the screen) |

Leave untouched: `Transitions/SwipeDownToDismiss/*` (nothing references it) and the test at
`Tests/Unit/MarketingConsent/MarketingConsentPromptCoordinatorTests.swift:158`.

**Do not** replace `UIDevice.current.orientation`, `windowScene.interfaceOrientation` or the
`userInterfaceIdiom` checks globally. Their results can differ on iPhone (for example a phone lying
flat). They get Duo-only branches in Phase 4 instead.

## Phase 3: Vertical bar (Duo only)

### 3.1 Screens that already work with no code change

- Every pushed settings screen (system back button on iOS 26+) and every modal sheet whose bar items
  are images (Settings, About, MyRuuvi, Discover, SignIn, SignInBenefits) moves to the vertical bar
  automatically. Phase 6 only checks that each item is **visible** (watch the `.clear` root tint), sits
  at the top, and doesn't cover content.
- **Verify → act:** DFU (`TagSettings/Submodules/DFU/View/SwiftUI/DFUUIView.swift:43-95`, which uses
  `NavigationView` with `.navigationBarItems(leading:)`). On the Duo outer display, check that the
  dismiss button is visible and works. If it isn't, apply `.toolbarVerticalBehavior(.disabled)` to the
  `NavigationView` content, wrapped in an `if #available(iOS 27.1, *)` view modifier. The modifier has
  no effect outside the Duo.

### 3.2 Shared mechanism: the "chrome mode" switch

Both custom-chrome screens get the same switch:

```swift
private enum ChromeMode { case standard /* today, untouched */, verticalBar /* Duo only */ }
private var chromeMode: ChromeMode {
    RuuviDuoLayout.isVerticalBarActive(traitCollection) ? .verticalBar : .standard
}
```

- In `viewDidLoad`, on iOS 27.1+, call
  `registerForTraitChanges(RuuviDuoLayout.traitsAffectingVerticalBar) { (vc: Self, _) in vc.applyChromeMode(animated: true) }`.
- `applyChromeMode`:
  - `.standard`: the current code exactly (nav bar hidden on iOS 26+, custom header complete).
  - `.verticalBar`: show the nav bar, set the `navigationItem` items below, and hide only the header
    buttons that moved. The logo and the activity indicator stay in the custom header, so the overall
    look is unchanged.
- In the existing `viewWillAppear` iOS 26 branches, replace `setNavigationBarHidden(true, …)` with
  `setNavigationBarHidden(chromeMode == .standard, …)`. Leave the `viewWillDisappear` branches as they
  are.
- Give every bar item an **icon and a title**. Title-only and custom-view items are never shown
  vertically, and a horizontal-only item disappears when no horizontal bar exists. Set `tintColor`
  explicitly on every item.
- Only add the items in `.verticalBar` mode. Remove them (`navigationItem.leftBarButtonItems = nil`,
  etc.) when going back to `.standard`.

### 3.3 Dashboard: `Dashboard/View/DashboardViewController.swift`

In `.verticalBar` mode:

| Item | Spec | Replaces header view |
|---|---|---|
| Menu (leading, top of bar) | `UIBarButtonItem(title: <Menu>, image: RuuviAsset.baselineMenuWhite48pt.image, target: self, action: #selector(handleMenuButtonTap))`, tint `RuuviColor.menuTintColor.color` | `menuButton` (:85) |
| View (trailing) | `UIBarButtonItem(title: RuuviLocalization.view, image: UIImage(systemName: "square.grid.2x2"), primaryAction: nil, menu: viewToggleMenuOptions())`, tint `RuuviColor.logoTintColor.color` | `viewButton` (:99). The text button can't go vertical, so it needs an icon |
| Search (trailing, only when `flags.showDashboardSensorSearch`) | `UIBarButtonItem(title: <Search>, image: UIImage(systemName: "magnifyingglass"), target: self, action: #selector(handleSearchButtonTap))` | `searchButton` (:145) |

- Put Menu in `navigationItem.leftBarButtonItems`, and View plus Search in `rightBarButtonItems`.
  Set `visibilityPriority = .high` on View (iOS 27).
- `viewButton.updateMenu(with:)` is called at `:30`, `:37` and `:43`. Route those calls through one new
  `refreshViewMenu()` that also sets `viewBarItem.menu = viewToggleMenuOptions()`.
- Search keeps working unchanged. `searchContainerView` still overlays `customHeaderView`, which
  still exists and still holds the logo.
- In `.verticalBar` mode, hide `menuButton`, `viewButton` and `searchButton` in `customHeaderView`
  and keep `headerLeftContainer`'s logo. Leave the constraints in place; hiding is enough.
- The pre-iOS 26 path (`setupNavigationBarItems`, `activateSearchLegacy`) is never reached on the
  Duo. Don't touch it.

### 3.4 Full Sensor Card: `Full Sensor Card/View/CardsBaseViewController.swift`

In `.verticalBar` mode:

| Item | Spec | Replaces |
|---|---|---|
| Back (leading, top) | `UIBarButtonItem(title: <Back>, image: RuuviAsset.chevronBack.image, target: self, action: #selector(backButtonDidTap))`, tint `.white`, plus `navigationItem.hidesBackButton = true` (this keeps the existing `output?.viewDidTapBackButton()` flow) | `backButton` (:114) |
| 4 tab items, one per `CardsMenuType.allCases`, as one `UIBarButtonItemGroup` in `trailingItemGroups` | `image: menuType.icon` (`Extensions/CardsMenuType+Extension.swift`), title = the tab name, tint `.white`, `visibilityPriority = .high`. On tap, call `menuBarView.setSelectedTab(type)`, which fires the existing `onTabChanged` → `showTabViewController(for:)` path. Set `isSelected` on the current tab's item wherever the selection changes, in `showTabViewController(for:)` at `:614` | `menuBarView` (`CardsMenuBarView`, header trailing, :372) |

- `menuBarView` stays in the hierarchy (hidden) and remains the single source of truth for the
  selected tab.
- **Alerts badge.** `CardsMenuBarView.updateAlertState(for:)` → `CardsMenuButton.updateAlertState(for:)`
  works out the bell image, tint, count and triggered state. Move that calculation into a pure
  `AlertBellState.make(for: snapshot)` that `CardsMenuButton` renders exactly as it does today. In
  `.verticalBar` mode the alerts bar item uses the same state: `image`, `tintColor`, and
  `badge = count > 0 ? .count(count) : nil`. The bell animation is dropped in the vertical bar.
- In `.verticalBar` mode, hide `backButton` and `menuBarView` in the header. Keep the logo and the
  activity indicator. The secondary toolbar (arrows and sensor name), the tab content and the footer
  don't change.

### 3.5 Strings

Reuse existing keys wherever they exist: `RuuviLocalization.view`, `.close`, `Settings.navigationItem.title`,
`TagSettings.Label.alerts.text`, `onboardingHistory`, and any existing tab or measurement title. New
keys (for example Menu, Search, Back) go in the **`station.localization` submodule**, which currently
has uncommitted changes, so coordinate first. Then regenerate `RuuviLocalization.swift` with the
project's SwiftGen step (`make xcodeproj`).

## Phase 4: Inner display, folding and resizing (Duo only)

### 4.1 Dashboard columns: `DashboardViewController.swift:1229-1236`
Add as the first line: `if RuuviDuoLayout.isFoldingDisplay(collectionView) { return 2 }`. That gives an
even count in both orientations, so the grid splits cleanly at the fold. The outer display keeps the
phone logic.

### 4.2 Measurement grid: `CardsMeasurementPageViewController.swift:45-82`
Add a `isFoldingDisplay: Bool` parameter to `ColumnConfig.forCurrentDevice`. Callers at
`:201`, `:377`, `:387`, `:491` and `:554` pass `RuuviDuoLayout.isFoldingDisplay(view)`, plus the
container **size**. Add a Duo branch before the existing branches:
- container wider than tall: `iPadLandscapeColumns` (4) and `iPadLandscapeHorizontalPadding` (80). Four
  columns split 2 | 2 around the book-style fold.
- otherwise: `iPadPortraitColumns` (3) and `iPadPortraitHorizontalPadding` (60). The fold is horizontal
  in this pose, and scrolling content doesn't need to move away from it.

The iPad and iPhone branches stay byte-for-byte the same. The Duo outer display uses the iPhone branch.

### 4.3 Graph and fade layout: "landscape layout" is off on the folding display
- `CardsGraphViewController.swift:156-164` (`isLandscapeLayout`) and `:1195-1212`
  (`currentFadeTransitionHeight`): add `if RuuviDuoLayout.isFoldingDisplay(view) { return false }` (or the
  portrait height) as the first statement. The inner display's interface orientation isn't reliable, and
  its height suits the multi-chart layout. The chart-size menu items stay available.
- `ScrollViewEdgeFader.swift:304-326`: same guard, using `scrollView`.
- `CardsGraphPresenter.swift:882` decides the swipe-up hint with `UIWindow.isLandscape`. Expose the
  view's existing `isLandscapeLayout` through the graph view input protocol as `usesLandscapeChartLayout`
  and have the presenter use that. On iPhone and iPad both values come from the same scene's
  `interfaceOrientation`. On the Duo inner display the hint then never shows.

### 4.4 Orientation locks are ignored on the inner display
`AppUtility.lockOrientation(.portrait)` (onboarding `AppRouter.swift:28`, sign-in `DashboardRouter.swift:90`)
has no effect on the inner display. **Verify → act:** in Device Hub, open the onboarding pages
(`Modules/RuuviOnboard/.../RuuviOnboardViewController.swift`), SignInBenefits and SignIn on the inner
display in both orientations. For any screen whose content stretches badly or clips, cap the content to
`view.readableContentGuide`, centred, under `isFoldingDisplay(view)`. Don't change anything else.

Also verify `Modules/RuuviFirmware/.../RuuviBoardView.swift:5-28`. `isPortrait` comes from
`interfaceOrientation` and starts as `false`. If it is wrong on the inner display, derive it from the
`GeometryReader` size, gated on `horizontalSizeClass == .regular && verticalSizeClass == .regular` with
`UIDevice.current.userInterfaceIdiom == .phone`. This is the SwiftUI equivalent of the gate.

### 4.5 Live resizing between the outer and inner displays
Opening and closing the device resizes the window (`viewWillTransition`). Anything computed once has to
pick up the new display:
- **Measurement details sheet.** Today `maxHeight` is taken once in `MeasurementDetailsCoordinator.start()`.
  Store the `UIScreen` it was computed for (`baseViewController.view.window?.windowScene?.screen`).
  Change `SheetConfiguration.maxHeight` (`Extensions/UIViewController+BottomSheet.swift:4-18`) to a
  closure that the detent resolver evaluates (`:86-93`). The closure returns the captured value
  **unless the scene's screen object has changed**; in that case it recomputes `topPadding` and the
  max height. Screen identity only changes on the Duo, so iPhone rotation keeps today's exact
  behaviour. Pass the new max into `MeasurementDetailsViewController` as well (its
  `maximumSheetHeight` is used in `updatePreferredContentSize()` at `:1101`).
- **Side menu** (`Menu/Transition/Table/MenuTableTransitionManager.swift:4-13`): the width is
  `min(min(w,h)*0.75, 260)`, which is 260 on both Duo displays. **Verify** only. No change expected.
- Dashboard (`viewWillTransition` → `updateSnapshot`) and the measurement grid
  (`updateLayoutForRotation`) already recompute on resize. Verify only.

### 4.6 Keep custom interactive UI off the fold
System alerts, sheets, menus and popovers move away from the fold on their own. Only custom UI needs work:
- **`Common/RuuviPresenters/.../Dialog/RuuviDialogViewController.swift:28-53`** (the marketing consent
  dialog, centred in the safe area). In `viewDidLayoutSubviews`, read `RuuviDuoLayout.activeFolds(in: view)`.
  - If a fold is **horizontal** (fold frame wider than tall), centre the dialog in the area below the
    fold. The HIG puts interactive content in the bottom half for this pose.
  - If it is **vertical**, centre it in the trailing half.
  - Do this with a `UILayoutGuide` for the chosen region. Activate the guide's centre constraints and
    deactivate the safe-area centre constraints. With no fold, use the original constraints.
  - Keep the existing width and height limits, measured against the region.
- Not interactive, so left as is: the toast (`ActivityPresenterRuuviLogo`), the chart marker, and the
  GestureInstructions hint (which 4.3 already suppresses on the inner display).
- Grids and lists scroll, so per Apple they don't need to move away from the fold. 4.1 and 4.2 already
  use even column counts.

## Phase 5: App Store assets

- Screenshots taken from the iPhone Duo simulator (`xcrun simctl io booted screenshot`):
  - outer display **1398×2034** (portrait)
  - inner display **2853×2007** (landscape, book pose) or 2007×2853

  Do this for each locale folder (`en-US`, `de-DE`, `fi`, `fr-FR`, `sv`). Follow the existing numbering:
  01–05 are iPhone and 11–18 are iPad. Use **21–25** for the outer display and **31–35** for the inner
  display.
- Uploading screenshots unlocks the "optimized for iPhone Duo" badge. They become **required from
  April 2027** for builds made with the iOS 27.1 SDK or later.
- **Verify → act:** fastlane `deliver` 2.240.1 identifies the device from the pixel size. If it rejects
  the Duo sizes, upgrade fastlane in the `Gemfile`. If no version supports them yet, upload these two
  sets by hand in App Store Connect.

## Phase 6: Verification (required before merge)

**6.1 iPhone and iPad must not change.** Build the final branch and capture the same screens as the
Phase 0 baseline:
- Devices: iPhone 17 Pro (portrait and landscape), iPhone 17 Pro Max (landscape), the smallest iPhone
  runtime available, iPad Pro 13" (portrait and landscape).
- Runtimes: iOS 27.2, plus iOS 26.x if installed (covers the code paths before 27.1).
- Screens:
  - Onboarding page 1
  - Dashboard: image cards, simple cards, empty state signed in and out, search active
  - Side menu
  - Full Sensor Card: all 4 tabs, Graph in landscape
  - Measurement details sheet
  - Settings root and one pushed screen
  - About, MyRuuvi, SignIn, Discover, DFU
  - Marketing consent dialog

Compare the images pixel by pixel (for example ImageMagick `compare -metric AE`). Mask clock, battery
and live readings. Any other difference blocks the merge.

**6.2 iPhone Duo functional matrix** (Device Hub, manual poses):
- Poses: outer portrait, outer landscape, inner open portrait, inner open landscape, partially folded
  book-style, partially folded laptop-style.
- Check each pose with each of these open: Dashboard, Card on every tab, measurement details sheet,
  side menu, a settings push, a modal sheet, the consent dialog.
- Also open and close the device while each of those is showing.

Pass criteria:
- Bars are vertical wherever the system puts them there.
- No action has disappeared. Each one is in the bar, the overflow menu or the header.
- Back or Close is at the top.
- Nothing is under the vertical bar, the status bar or the camera.
- No custom interactive element sits on the fold.
- The layout updates on open and close without a relaunch.
- The selected tab and the open sheet survive the resize.

**6.3** The unit test from Phase 1 passes. `swiftlint` is clean.

## Commit order (one branch, e.g. `feature/iphone-duo`)

1. `ci: build with Xcode 27.2` (Phase 0)
2. `feat(duo): RuuviDuoLayout gates + test` (Phase 1; do its Verify → act step before writing Phases 3–4)
3. `refactor: replace deprecated UIScreen.main (no behaviour change)` (Phase 2)
4. `feat(duo): adopt vertical bar on Dashboard and Full Sensor Card` (Phase 3)
5. `feat(duo): folding display layouts, resize handling, fold avoidance` (Phase 4)
6. `chore(duo): App Store screenshots` (Phase 5)

## Known risks

| Risk | Mitigation |
|---|---|
| The GitHub runner image doesn't have Xcode 27.x yet | Phase 0 step 1. Until it does, build releases on a self-hosted or local Mac |
| The gate assumptions are wrong (inactive division region, layout on fold, vertical status bar with a hidden nav bar) | The **Verify → act** steps in Phase 1, with fallbacks already defined |
| The `.clear` root nav tint makes system items invisible in the vertical bar | Explicit item tints (3.2). Phase 6.2 checks every screen |
| New strings need the localization submodule, which has local changes | 3.5: reuse first, coordinate any new keys |
| Resizable iPhone Mirroring on macOS 27 could hit the SwiftUI size-class gate in 4.4 | Only used there, and only if that verify step fails. Every UIKit gate depends on reserved regions or the vertical bar, which Mirroring doesn't produce |

---

## Implementation notes (2026-11-07, branch `feature/iphone-duo`)

### Differences from the plan above
- **`RuuviAppGeometry`** (removed on 2026-11-08, see "Resizable windows" below) returned the
  bounds and scale of the *scene's screen*, not the window. On iPadOS 26+ the app can run in a resizable
  window, and the old `UIScreen.main.bounds` was the screen's bounds, so this keeps iPad identical in that
  case too. It also has `screenTraits(for:)`, which `NoSensorView` uses.
- **Bar titles** live in `RuuviDuoStrings` (in `Common/RuuviLocalization/Sources/RuuviDuoLayout.swift`), not in
  generated SwiftGen keys. Generated keys would break CI until the shared translations repo has them.
  `RuuviDuoStrings` uses the same `Localizable` table with English fallbacks.
  - Keys to add as `ident_ios` in `station.localization`: `menu`, `search`, `measurements`, plus `back` and
    `history`. The last two already exist there for Android and web, so only the iOS ident is missing.
  - Reused keys: `view`, `TagSettings.Label.alerts.text`, `TagSettings.navigationItem.title`.
- **Alerts badge:** `RuuviTagCardSnapshot.alertBadgeData()` already is the pure state function, so no
  `AlertBellState` was extracted. The bar item mirrors it: count, orange when triggered, `99+`.
- **Dialog fold avoidance:** always adds a `UIHingeInteraction`. Folding doesn't change the view size, and
  the interaction only triggers a re-layout when a hinge exists.
- **Unit tests:** a new `station.duoLayoutTests` target (`Apps/RuuviStation/Tests/Unit/DuoLayout/`), added to
  the `station` scheme.
- **CI:** `testflight.yml` and `firebase.yml` (the two workflows that build binaries) now run on
  `runs-on: xcode-27` with `xcode-version: '27.1'`.
  - GitHub's `macos-26` image ships only Xcode 26.x; Xcode 27 is on the separate `xcode-27` image
    (macOS 27).
  - The version is pinned exactly because a range like `^27.1` would also match the image's 27.2
    release candidate.
  - Check that Ruby, bundler and fastlane 2.240.1 work on that image on the first run.
  - The App Store metadata and submit workflows don't compile, so they are unchanged.
- **`RuuviAppGeometry`** returns `UIScreen.main` on every device without a hinge. Only on iPhone Duo
  does it return the scene's screen. This keeps an iPad window on an external display (Stage Manager)
  identical to `main`.
- **Onboarding.**
  - The pages stay full width, so backgrounds like the teal gateway footer run edge to edge.
  - On the Duo, the paging collection view uses `contentInsetAdjustmentBehavior = .never`. The default
    absorbed the side safe area as content inset, so the pages never saw it and their text ran under
    the side bar. The pages' existing safe-area constraints now inset the text.
  - The page that was showing is captured before a size transition (opening or closing the device)
    and restored afterwards.
  - The gateway footer's row is centred in the safe area on the Duo, using
    `RuuviVerticalBarConstraintSwitch`.
- **Orientation lock on the inner display.** Onboarding and sign-in lock to portrait. On the Duo's
  inner display that showed the app as a portrait box in the middle of the screen.
  - A `UIHingeInteraction` on the app window lifts the lock while the device is open
    (`AppUtility.supportedOrientations`). The outer display keeps the lock.
  - Devices without a hinge (every iPhone and iPad) are unaffected.
- **Sign in:** limited to the safe area while the vertical bar is active, using the constraint switch.
- **Sensor card tabs: native `UITabBarController` on the Duo.**
  - Devices with a hinge only: the four tab screens are owned by a tab bar controller embedded in the
    card screen. It gets the system tab bar with its native behaviour: the Liquid Glass selection lens,
    drag to switch, animated selection and the alert badge.
  - The tab bar controller's view spans the whole card screen, which is needed for the system to place
    its tab bar in the vertical bar. Each tab is wrapped in a container that pins the tab view exactly
    like the old custom container did.
  - Selection goes through the existing presenter in both directions.
  - Where there is no vertical bar (inner display in portrait), the native tab bar is hidden and the
    custom tab row drives the tabs.
  - The system first draws the vertical tab bar at the wrong edge (bottom-leading). It only moves into
    the shared column under Back on the next tab bar layout, so the card re-shows it once it is on
    screen.
  - Under Back, the existing safe area already reserves the column, so content never overlaps.
  - A host design (a pushed `UITabBarController` containing the card screen) was tried and rejected:
    the card screen's vertical-bar layout didn't switch on inside it and its tab content didn't show.
  - iPhone and iPad keep the custom tab row and the original embedding.
- **Sensor card logo:** a 12pt leading inset in vertical-bar mode, as on the dashboard.
- **Simulator only:** the "Bluetooth is not enabled" alert is no longer shown, because the simulator
  has no Bluetooth. The check is compile-time, so device builds are unchanged. It covers the dashboard,
  the card, the graph and Discover.
- **Verification harness (outside the repo).** A scratch XCUITest project drives the installed app by
  bundle id. It opens a sensor card (a test sensor is injected into the local DB), steps through all
  tabs, and swipes through onboarding.

### Screen coverage audit (every view controller and SwiftUI screen)

**Why the first pass missed screens.** The plan only searched for specific code patterns: custom bars and
back buttons, screen size and orientation code, and custom popups. It never checked each screen for
whether its content stays inside the horizontal safe area. On a regular iPhone in portrait those side
insets are 0, so the problem only appears on the Duo, where the status bar and the vertical bar sit on a
side. The pixel diff proves "unchanged from `main`", so it couldn't catch problems that already existed
on `main`.

**Method.** All 42 view controllers, the SwiftUI screens and the storyboards were reviewed with one rule.
Content must be pinned to the safe area, layout margins, a safe-area ancestor, or `contentView` in table
cells. Content pinned to view edges, to `width == view.width`, or using `ignoresSafeArea` on foreground
content is a risk.

| Area | Screens | Result |
|---|---|---|
| Launch | Onboarding (4 page types) | **Fixed.** On the Duo the paging collection view stops absorbing the side safe area, so the full-width pages inset their text. The gateway footer row is pinned to the safe area. The current page is restored after a size transition. |
| Account | Sign in, sign-in benefits | **Fixed**, using the same constraint switch. |
| Dashboard | Dashboard, no-sensor view, banner, cells | OK (safe area) |
| Menu | Side menu drawer, newsletter card | **Fixed.** The storyboard container was pinned to the root view; it now switches to the safe area. |
| Sensor card | Base, measurements, graph, alerts (SwiftUI), sensor settings (SwiftUI), LED brightness, notes, background selection, visibility (SwiftUI) | OK: everything is under the safe-area tab container or uses safe anchors. |
| Sensor card | Measurement details sheet | **Fixed.** The scroll view was pinned to view edges; it now uses the constraint switch. |
| Sensor settings | Offset correction, owner, force claim, remove sensor, share | OK |
| Sensor settings | Firmware update (DFU, SwiftUI) | **Fixed.** It had `edgesIgnoringSafeArea(.all)` on its content. While `toolbarVerticalEdge` is set, it now keeps the side safe area and only the background extends. |
| Firmware | Firmware flow (RuuviFirmware, SwiftUI) | OK |
| Discover | Add sensor | OK. Minor: the action button is centred on the view rather than the safe area. |
| App settings | Settings, appearance, chart, defaults, devices, heartbeat, notifications, cloud, selection, units | Cells and containers OK. **Fixed:** the section footers of chart, notifications and cloud (`fillSuperviewAvoidingVerticalBar`, with a table reload when the bar toggles). Heartbeat's footer is edge-pinned too, but its table sits in a container pinned to the safe area (`Heartbeat.storyboard`), so it can't reach under the bar. |
| Other | About, My Ruuvi, marketing consent dialog, toast | OK |
| Not changed | Feature toggles (hidden; enabled by shaking Settings), alert debug log (FLEX, debug only) | Header and text view pinned to edges. Not shipped-critical. |

Every fix uses the vertical-bar gate. Plain safe-area pinning would also move these screens on notched
iPhones in landscape (Settings, DFU and the details sheet aren't orientation-locked), which the hard rule
doesn't allow.

### Verified (final run, 2026-11-08)
- Built with Xcode 27.2 RC. The baseline (untouched `main`) needed no changes. SwiftLint reports no new
  warnings; the two `function_body_length` warnings already exist on `main`.
- **Unit tests:**
  - iPhone 18 Pro (iOS 27.2): all pass. That's the existing 15 + 25 plus the 5 new Duo gate tests.
  - iPad Pro 13" (M5): the 5 Duo gate tests pass and are not skipped. They cover no hinge, no vertical
    bar, no fold, orientation locks kept, `RuuviAppGeometry` equal to `UIScreen.main`, and the
    constraint switch keeping the original constraints.
- **iPhone 18 Pro, pixel diff against `main`:** identical on freshly erased simulators. That covers
  onboarding, the dashboard (empty and with a sensor), all four sensor card tabs and the measurement
  details sheet, which the UI harness opens by tapping a measurement tile.
  - The `main` side of the card comparison was `main` plus only the simulator Bluetooth-alert
    suppression; without it the alert blocks navigation in the simulator.
- **iPad Pro 13" (M5):**
  - Onboarding and the empty dashboard are identical apart from the status bar date (the run crossed
    midnight).
  - Card settings tab: identical. Card graph tab: only the "… ago" timestamp differs.
  - The other card frames differed only in whether the injected test reading had loaded ("No data
    during the last 10 days"). With the same database, the two builds render the dashboard
    identically, so this is the harness's test-data timing, not the code.
- **iPhone Duo, outer display (UI harness):**
  - Dashboard: Menu and View sit in the vertical bar.
  - Sensor card: the native tab bar sits in the shared column under Back with all four tabs working.
    Content stays clear of the column, Alerts and Settings keep the header background, and tapping a
    tile opens the details sheet, which stays clear of the side column.
  - Onboarding: text stays clear of the side bar, the teal gateway footer runs edge to edge with a
    readable row, and the current page is kept through rotations.

### Not verified yet (manual, in Device Hub)
These need Device Hub's fold buttons and in-app navigation. Use a test sensor; the SQL below adds one.
1. **Sensor card on the inner display and in partially folded poses:** the native tab bar's placement,
   and the custom tab row in inner portrait. The outer display is verified by the UI harness (see
   Verified).
2. **Device fully open (inner display, both orientations):**
   - dashboard has 2 columns
   - measurement grid has 4 columns in landscape and 3 in portrait
   - graph uses the multi-chart layout and shows no swipe-up hint
   - in inner portrait (no vertical bar) the original header returns
3. **Partially open:** the marketing consent dialog sits below or beside the fold.
4. **Open/close with the measurement details sheet showing:** the sheet's max height follows the new
   display.
5. **Inner display:** onboarding and sign-in still lay out acceptably even though they are portrait-locked
   (step 4.4). The firmware board view orientation (`RuuviBoardView`) looks right.
6. **Outer display:** the DFU sheet's dismiss button is reachable (step 3.1).
7. **Onboarding paging:** swipe through all pages on the outer display, then open and close the device
   partway through. Each swipe should move exactly one page, and the current page should stay in place.
8. **Content clear of the side bar on the outer display (both landscape rotations):** side menu,
   Settings section footers (chart, notifications, cloud), the measurement details sheet, and DFU.

Test sensor, for a simulator where the app has run once (adjust `C`):
```sh
C=$(xcrun simctl get_app_container <udid> com.ruuvi.station data)
sqlite3 "$C/Documents/grdb.sqlite" "INSERT OR REPLACE INTO ruuvi_tag_sensors (id, mac, name, version, isConnectable, isClaimed, isOwner, isCloudSensor, canShare, sharedTo, sharedToPending) VALUES ('DE:AD:BE:EF:00:01','DE:AD:BE:EF:00:01','Living room',5,1,0,1,0,0,'',''); INSERT OR REPLACE INTO ruuvi_tag_sensor_record_latest (id, ruuviTagId, date, source, mac, version, celsius, relativeHumidityInPercent, hectopascals, volts, temperatureOffset, humidityOffset, pressureOffset) VALUES ('DE:AD:BE:EF:00:01-latest','DE:AD:BE:EF:00:01',strftime('%Y-%m-%d %H:%M:%f','now'),'advertisement','DE:AD:BE:EF:00:01',5,21.4,0.452,1012.8,3.01,0,0,0);"
```

### Open items
- **App Store screenshots (Phase 5):** not produced. These need real content. fastlane 2.240.1 (the
  `deliver` lane) has no iPhone Duo display type, so upload the 1398×2034 and 2007×2853 sets in App Store
  Connect, or update fastlane once it supports them. They are required from April 2027 for builds made
  with the iOS 27.1+ SDK.
- **First CI run on the `xcode-27` image:** check that Ruby, bundler and fastlane 2.240.1 work there.
- **Hand-uploaded Duo screenshots get wiped.** `sync_app_store_metadata` with
  `overwrite_screenshots:true` deletes every screenshot set of each uploaded locale, including the Duo
  sets fastlane can't classify. Don't overwrite until fastlane supports the Duo display types, or keep a
  copy to re-upload by hand.
- **`UIRequiresFullScreen` on iOS 27: decided, see "Resizable windows" below.** With the iOS 27 SDK,
  iOS 27 always resizes the scene. No value of `UIRequiresFullScreenIgnoredStartingWithVersion` keeps
  iOS 27 full screen. The key only chooses between discrete resizing (key absent) and live resizing.
- **The iOS 27 SDK bump itself** wasn't compared against the shipped 3.9.0 build, which used the iOS 26
  SDK. Every comparison here is `main` built with Xcode 27.2 against the branch built with Xcode 27.2.
- **Translations:** the new bar titles use English until the shared translations repo adds `ident_ios`
  for `menu`, `search` and `measurements`, and for the existing `back` and `history` entries.
- **Empty dashboard when partially folded:** the Sign in / Add sensor buttons are centred and can sit on
  a horizontal fold. They're inside a scroll view, which Apple exempts from moving off the fold, so they
  were left as they are.

---

## Resizable windows (2026-11-08)

Since the iOS 27 SDK, iPadOS 27 resizes the app even with `UIRequiresFullScreen`
([TN3192](https://developer.apple.com/documentation/technotes/tn3192-migrating-your-app-from-the-deprecated-uirequiresfullscreen-key)).
The app now supports resizable windows. Several Duo-only gates from the phases above were replaced
along the way.

### Info.plist
- `UIRequiresFullScreen` stays `true`.
- `UIRequiresFullScreenIgnoredStartingWithVersion = "27"` (a string) is added. iOS/iPadOS 27 and later
  resize live, and iPadOS 16–26 stay full screen as before.
- `SceneDelegate` sets a preferred minimum window width of 375pt.

### Rules
- **Layout from size classes, not device type or orientation.** `RuuviLayoutClass`
  (`Common/RuuviLocalization/Sources/RuuviLayoutClass.swift`) maps:
  - regular × regular → `.regular`, today's iPad layout;
  - compact height → `.compactHeight`, today's iPhone landscape (Pro Max landscape too);
  - everything else → `.compactWidth`, today's iPhone portrait.
- **Content shown in a sheet reads the window's class (`ruuviWindowLayoutClass`).** On iPad, UIKit gives
  a floating, form-sheet-sized sheet a compact width even on a full-screen iPad.
- **Grids fit columns to the width they actually have** (`RuuviGridFit`). The limits are chosen so that
  full-screen iPhones and iPads keep today's counts:

  | Grid | Columns | Max column width |
  |---|---|---|
  | Dashboard | 1–3 | 516pt |
  | Measurements, regular layout | 3–4 | 308pt (even when a vertical fold crosses it) |
  | Background Selection, regular layout | 5 or 8 | 206pt |

  One known difference: 768×1024pt iPads (iPad 5th/6th gen, mini 5, Pro 9.7") in landscape now get the
  portrait counts. Their width is the same as a 12.9" iPad in portrait.
- **The graph pages one chart per screen** in compact height, or when 3 stacked charts would each be
  more than 4× wider than tall. This keeps iPad landscape paged. The Duo inner display now pages in
  landscape too.
- **Font sizes stay by device type** (`UIDevice.isTablet()`, the +2pt in RuuviFonts). So do metrics that
  only exist to fit that text.
- **Orientation locks stay** for onboarding and sign-in on iPhone. Resizable iPad windows ignore them,
  so those screens now also work in landscape and at any size.
- **Custom headers clear the window controls** with `RuuviWindowControlsInsetUpdater`. Its inset is 0
  unless the window is smaller than the screen. Don't use the corner-adapted safe area directly: it also
  avoids the rounded display corners and would move headers on every iPhone and iPad.

### Removed
- `RuuviAppGeometry`.
- `RuuviDuoLayout.isFoldingDisplay`; use `hasVerticalFold(in:)`.
- `GlobalHelpers.isDeviceTablet()` and `isDeviceLandscape()`.
- `UIWindow.isLandscape` and `isPortrait`.
- The onboarding `isDuoContext` gate.
- The DFU `isFoldableDevice` gate.
- The graph's `allowsLandscapeSwipeHint`.

### Verified
- Before/after screenshots against HEAD `79c0116ce`, iPhone 18 Pro and iPad Pro 13", portrait and
  landscape. Covered screens:
  - Dashboard, menu, Discover, sign-in, card tabs, details sheet.
  - Background Selection, Remove sensor, firmware.
  - App settings, About, onboarding.

  They are pixel-identical except for time-dependent text and data. On iPad, sign-in and onboarding now
  rotate with the device, because the portrait lock no longer applies to a resizable app.
- Unit tests: `RuuviLayoutClassTests` checks the fit limits against every iPhone and iPad screen size.
- Live resizing on iPadOS 27 (simulator, Windowed Apps on) on the dashboard, sensor card and onboarding:
  - The window never gets narrower than 375pt.
  - Headers sit clear of the window controls, including in a maximized window.
  - The grids change column count as the window is resized.
  - Short windows report compact height: 3 measurement columns and a paged graph.
  - Onboarding keeps its page.
- Not re-checked after this change: the Duo inner display. Device Hub fold poses can't be automated.
  The outer display matches the earlier Duo build.
