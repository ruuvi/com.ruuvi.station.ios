// swiftlint:disable file_length

import RuuviLocalization
import UIKit
import Combine
import RuuviOntology

/// Base view controller that manages multiple tab view controllers
final class CardsBaseViewController: UIViewController {

    // MARK: - Constants
    private enum Constants {
        enum Layout {
            static let spaceUntilSecondaryToolbarExtraMargin: CGFloat = 10
            static let backButtonSize = CGSize(width: 44, height: 44)
            static let ruuviLogoSize = CGSize(width: 90, height: 22)
            static let menuBarHeight: CGFloat = 44
            static let headerHorizontalPadding: CGFloat = 12
            static let headerItemSpacing: CGFloat = 12
            static let headerLogoSpacing: CGFloat = 8
            static let headerMinimumSpacing: CGFloat = 4
            static let secondaryToolbarTopPadding: CGFloat = 2
            static let arrowButtonSidePadding: CGFloat = 4
            static let arrowButtonIconTopPadding: CGFloat = 7
            static let titleStackSpacing: CGFloat = 2
            static let tagNameLabelPadding = UIEdgeInsets(top: 4, left: 4, bottom: 6, right: 4)
            static let tabContainerVerticalPadding: CGFloat = 8
            static let sourceUpdateStackSpacing: CGFloat = 6
            static let dataSourceIconMaxWidth: CGFloat = 22
            static let footerStackSpacing: CGFloat = 4
            static let footerStackHorizontalPadding: CGFloat = 20
            static let footerStackHeight: CGFloat = 24
        }

        enum Animation {
            static let tabTransitionDuration: Double = 0.2
            static let tabTransitionDelay: Double = 0
            static let tabTransitionDamping: CGFloat = 0.6
            static let tabTransitionVelocity: CGFloat = 0.4
            static let chartBackgroundTransitionDuration: Double = 0.3
        }

        enum Typography {
            static let tagNameLabelFontSize: CGFloat = 20
            static let pageTitleLabelFontSize: CGFloat = 14
            static let batteryLabelFontSize: CGFloat = 10
            static let batteryIconSize: CGFloat = 16
            static let updatedAtLabelFontSize: CGFloat = 10
            static let tagNameLabelLines: Int = 2
            static let pageTitleLabelLines: Int = 1
            static let updatedAtLabelLines: Int = 0
        }

        enum Alpha {
            static let dataSourceIconAlpha: CGFloat = 0.7
            static let whiteWithAlpha: CGFloat = 0.8
            static let chartBackgroundVisible: CGFloat = 1
            static let chartBackgroundHidden: CGFloat = 0
        }
    }

    // MARK: - Public Properties
    weak var output: CardsBaseViewOutput?
    var spaceUntilSecondaryToolbar: CGFloat {
        view.layoutIfNeeded()
        return view.safeAreaInsets.top +
            headerContainerView.frame.height +
            secondaryToolbarView.frame.height +
            Constants.Layout.spaceUntilSecondaryToolbarExtraMargin
    }

    // MARK: Properties
    /// Mapping of tab identifier to its view controller
    private let tabs: [CardsMenuType: UIViewController]

    /// Currently visible tab
    private var activeTab: CardsMenuType

    // MARK: - Details view
    private var detailsCoordinator: MeasurementDetailsCoordinator?

    // MARK: - State
    private var currentSnapshots: [RuuviTagCardSnapshot] = []
    private var currentSnapshotIndex: Int = 0
    private var currentSnapshot: RuuviTagCardSnapshot? {
        didSet {
            reconfigureSnapshotObservation()
        }
    }
    private var isUpdatingUI = false
    private var cancellables: Set<AnyCancellable> = []

    // MARK: - iPhone Duo vertical bar
    /// `true` while back and the tabs are shown in the system vertical bar (iPhone Duo only).
    private var isVerticalBarChromeApplied = false
    private var headerLeadingStackLeadingConstraint: NSLayoutConstraint?
    /// Moves the back button and logo clear of the iPadOS window controls (no-op on iPhone and
    /// full-screen iPad); also carries the iPhone Duo vertical-bar inset as its base constant.
    private var headerWindowControlsInset: RuuviWindowControlsInsetUpdater?

    private lazy var backBarItem: UIBarButtonItem = {
        let item = UIBarButtonItem(
            title: RuuviDuoStrings.back,
            image: RuuviAsset.chevronBack.image.ruuviBarIcon(),
            target: self,
            action: #selector(backButtonDidTap)
        )
        item.tintColor = .white
        return item
    }()

    /// The tab items currently shown in the vertical bar (rebuilt on every selection change).
    private var tabBarItems: [CardsMenuType: UIBarButtonItem] = [:]

    /// iPhone Duo: the four tabs are owned by a native tab bar controller, so the system shows a real
    /// tab bar in the vertical bar with native selection behaviour. `nil` on iPhone and iPad, which
    /// keep the custom tab row.
    private var nativeTabBarController: UITabBarController?
    private var usesNativeTabBar: Bool { nativeTabBarController != nil }
    /// The containers the native tab bar controller shows (one per tab, wrapping `tabs`).
    private var nativeTabContainers: [CardsMenuType: UIViewController] = [:]

    // MARK: - Base UI Components
    private lazy var cardBackgroundView = CardsBackgroundView()
    private lazy var tabBackgroundView = UIView(color: .clear)
    private lazy var headerContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // Header
    // Ruuvi Logo
    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.ruuviLogo.image.withRenderingMode(.alwaysTemplate),
            contentMode: .scaleAspectFit
        )
        iv.tintColor = .white
        return iv
    }()

    // Action Buttons
    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.tintColor = .white
        let buttonImage = RuuviAsset.chevronBack.image
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .white
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        return ai
    }()

    private lazy var menuBarView: CardsMenuBarView = {
        let view = CardsMenuBarView()
        view.setSelectedTab(activeTab, notify: false)
        view.backgroundColor = .clear
        return view
    }()

    // Secondary Toolbar
    private lazy var secondaryToolbarView = UIView(color: .clear)
    private lazy var cardLeftArrowButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "chevron.left"),
            leadingPadding: 10,
            iconTopPadding: Constants.Layout.arrowButtonIconTopPadding
        )
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(cardLeftArrowButtonDidTap)
            )
        )
        return button
    }()

    private lazy var cardRightArrowButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "chevron.right"),
            trailingPadding: 10,
            iconTopPadding: Constants.Layout.arrowButtonIconTopPadding
        )
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(cardRightArrowButtonDidTap)
            )
        )
        return button
    }()

    private lazy var sensorNameSwipeView: CardsSensorNameSwipeView = {
        let view = CardsSensorNameSwipeView(
            font: UIFont.mulish(
                .extraBold,
                size: Constants.Typography.tagNameLabelFontSize
            ),
            numberOfLines: Constants.Typography.tagNameLabelLines
        )
        view.onNavigate = { [weak self] direction in
            self?.navigateFromSensorNameSwipe(direction) ?? false
        }
        return view
    }()

    private lazy var pageTitleLabel: UILabel = makePageTitleLabel()
    private lazy var titleStackView: UIStackView = makeTitleStackView()

    // MARK: - Tab Container
    private lazy var tabContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Footer Components
    private lazy var footerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var batteryLevelView: BatteryLevelView = {
        let view = BatteryLevelView()
        view
            .updateTextColor(
                with: .white.withAlphaComponent(
                    Constants.Alpha.whiteWithAlpha
                )
            )
        return view
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(Constants.Alpha.whiteWithAlpha)
        label.textAlignment = .left
        label.numberOfLines = Constants.Typography.updatedAtLabelLines
        label.font = UIFont.ruuviCaption2()
        return label
    }()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = Constants.Alpha.dataSourceIconAlpha
        iv.tintColor = .white.withAlphaComponent(Constants.Alpha.whiteWithAlpha)
        return iv
    }()

    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!
    private var footerStackHeightConstraint: NSLayoutConstraint!
    private var footerBottomToSafeConstraint: NSLayoutConstraint!
    private var footerBottomToViewConstraint: NSLayoutConstraint!
    private var tabContainerBottomToViewConstraint: NSLayoutConstraint!

    // MARK: - Init
    init(
        tabs: [CardsMenuType: UIViewController],
        activeTab: CardsMenuType
    ) {
        self.tabs = tabs
        self.activeTab = activeTab
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        registerVerticalBarObserver()
        startObservingAppState()
        TimestampUpdateService.shared.addSubscriber(self)
        updateCurrentSnapshotUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyVerticalBarChrome(updateNavigationBarVisibility: false)
        // The navigation bar only shows on iPhone Duo, where it hosts the vertical bar.
        navigationController?.setNavigationBarHidden(!isVerticalBarChromeApplied, animated: animated)
        output?.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            TimestampUpdateService.shared.removeSubscriber(self)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        TimestampUpdateService.shared.removeSubscriber(self)
    }
}

// MARK: - UI Setup
private extension CardsBaseViewController {
    func makePageTitleLabel() -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = Constants.Typography.pageTitleLabelLines
        label.font = UIFont.mulish(.bold, size: Constants.Typography.pageTitleLabelFontSize)
        label.alpha = 0
        label.isHidden = true
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    func makeTitleStackView() -> UIStackView {
        let stackView = UIStackView(arrangedSubviews: [sensorNameSwipeView, pageTitleLabel])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = Constants.Layout.titleStackSpacing
        stackView.setContentHuggingPriority(.required, for: .vertical)
        stackView.setContentCompressionResistancePriority(.required, for: .vertical)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    func setUpUI() {
        setUpBaseView()
        setUpHeaderView()
        setUpSecondaryToolbarView()
        setUpTabContainer()
        setUpFooterView()
        embedChildViewControllers()
        updateFooterVisibility(for: activeTab, animated: false)
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.primary.color

        view.addSubview(cardBackgroundView)
        cardBackgroundView.fillSuperview()

        view.addSubview(tabBackgroundView)
        tabBackgroundView.fillSuperview()
        updateTabBackground(for: activeTab, animated: false)
    }

    func setUpHeaderView() {
        view.addSubview(headerContainerView)
        headerContainerView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            size: .init(width: 0, height: 44)
        )

        let headerLeadingStack = UIStackView(arrangedSubviews: [backButton, ruuviLogoView])
        headerLeadingStack.axis = .horizontal
        headerLeadingStack.alignment = .center
        headerLeadingStack.spacing = 0
        headerLeadingStack.backgroundColor = .clear

        backButton.widthAnchor.constraint(equalToConstant: Constants.Layout.backButtonSize.width).isActive = true
        backButton.heightAnchor.constraint(equalToConstant: Constants.Layout.backButtonSize.height).isActive = true

        // The logo's width is set in `activateHeaderFittingConstraints`.
        ruuviLogoView.heightAnchor.constraint(equalToConstant: Constants.Layout.ruuviLogoSize.height).isActive = true

        headerContainerView.addSubview(headerLeadingStack)
        headerLeadingStackLeadingConstraint = headerLeadingStack
            .anchor(
                top: headerContainerView.topAnchor,
                leading: headerContainerView.safeLeftAnchor,
                bottom: headerContainerView.bottomAnchor,
                trailing: nil
            ).leading
        // The navigation bar is hidden, so nothing else makes room for the window controls of an
        // iPadOS window that doesn't fill the screen.
        headerWindowControlsInset = headerLeadingStackLeadingConstraint
            .map { RuuviWindowControlsInsetUpdater(constraint: $0, in: view) }

        headerContainerView.addSubview(menuBarView)
        menuBarView.anchor(
            top: headerContainerView.topAnchor,
            leading: nil,
            bottom: headerContainerView.bottomAnchor,
            trailing: headerContainerView.safeRightAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 4)
        )

        headerLeadingStack.setContentHuggingPriority(.required, for: .horizontal)
        menuBarView.setContentHuggingPriority(.required, for: .horizontal)
        menuBarView.setContentCompressionResistancePriority(.required, for: .horizontal)
        menuBarView.setContentHuggingPriority(.required, for: .vertical)
        menuBarView.setContentCompressionResistancePriority(.required, for: .vertical)
        menuBarView.heightAnchor
            .constraint(equalToConstant: Constants.Layout.menuBarHeight)
            .isActive = true

        headerContainerView.addSubview(activityIndicator)
        activateHeaderFittingConstraints(leadingStack: headerLeadingStack)

        menuBarView.onTabChanged = { [weak self] tab in
            self?.handleTabChange(tab)
        }
    }

    /// Keeps the header row (back button and logo, activity indicator, tabs) from overlapping in
    /// narrow windows, or when the window controls push the back button in. Nothing moves where
    /// the row fits (every iPhone 375pt and wider, full-screen iPad): the logo shrinks only when it
    /// would run into the tabs, and the activity indicator leaves the centre only to stay off the
    /// tabs (it was over the first tab below about 360pt) and, where there is room, off the logo.
    func activateHeaderFittingConstraints(leadingStack: UIStackView) {
        // Just below required: the logo is the part of the row that gives way when it doesn't fit.
        let ruuviLogoWidthConstraint = ruuviLogoView.widthAnchor.constraint(
            equalToConstant: Constants.Layout.ruuviLogoSize.width
        )
        ruuviLogoWidthConstraint.priority = .required - 1
        ruuviLogoView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.setContentCompressionResistancePriority(.required, for: .horizontal)

        let activityIndicatorCenterX = activityIndicator.centerXAnchor.constraint(
            equalTo: headerContainerView.centerXAnchor
        )
        activityIndicatorCenterX.priority = .defaultHigh
        // Below the logo's width: in a row too narrow for both, the indicator overlaps the logo.
        let activityIndicatorClearOfLogo = activityIndicator.leadingAnchor.constraint(
            greaterThanOrEqualTo: leadingStack.trailingAnchor,
            constant: Constants.Layout.headerMinimumSpacing
        )
        activityIndicatorClearOfLogo.priority = .required - 2

        NSLayoutConstraint.activate([
            ruuviLogoWidthConstraint,
            activityIndicatorCenterX,
            activityIndicator.centerYAnchor.constraint(equalTo: headerContainerView.centerYAnchor),
            activityIndicator.trailingAnchor.constraint(
                lessThanOrEqualTo: menuBarView.leadingAnchor,
                constant: -Constants.Layout.headerMinimumSpacing
            ),
            activityIndicatorClearOfLogo,
            leadingStack.trailingAnchor.constraint(
                lessThanOrEqualTo: menuBarView.leadingAnchor,
                constant: -Constants.Layout.headerLogoSpacing
            ),
        ])
    }

    func setUpSecondaryToolbarView() {
        view.addSubview(secondaryToolbarView)
        secondaryToolbarView.anchor(
            top: headerContainerView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: Constants.Layout.secondaryToolbarTopPadding,
                left: 0,
                bottom: 0,
                right: 0
            )
        )

        secondaryToolbarView.addSubview(cardLeftArrowButton)
        cardLeftArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: secondaryToolbarView.leadingAnchor,
            bottom: secondaryToolbarView.bottomAnchor,
            trailing: nil,
            padding: .init(
                top: 0,
                left: Constants.Layout.arrowButtonSidePadding,
                bottom: 0,
                right: 0
            )
        )

        secondaryToolbarView.addSubview(cardRightArrowButton)
        cardRightArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: nil,
            bottom: secondaryToolbarView.bottomAnchor,
            trailing: secondaryToolbarView.trailingAnchor,
            padding: .init(
                top: 0,
                left: 0,
                bottom: 0,
                right: Constants.Layout.arrowButtonSidePadding
            )
        )

        secondaryToolbarView.addSubview(titleStackView)
        titleStackView.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: cardLeftArrowButton.trailingAnchor,
            bottom: nil,
            trailing: cardRightArrowButton.leadingAnchor,
            padding: .init(
                top: Constants.Layout.tagNameLabelPadding.top,
                left: Constants.Layout.tagNameLabelPadding.left,
                bottom: 0,
                right: Constants.Layout.tagNameLabelPadding.right
            )
        )
        titleStackView.bottomAnchor.constraint(
            equalTo: secondaryToolbarView.bottomAnchor,
            constant: -Constants.Layout.tagNameLabelPadding.bottom
        ).isActive = true

        updateHeaderSubtitle(for: activeTab)
    }

    func setUpTabContainer() {
        view.addSubview(tabContainerView)

        tabContainerView.anchor(
            top: secondaryToolbarView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: Constants.Layout.tabContainerVerticalPadding,
                left: 0,
                bottom: Constants.Layout.tabContainerVerticalPadding,
                right: 0
            )
        )

        tabContainerBottomToViewConstraint = tabContainerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor
        )
        tabContainerBottomToViewConstraint.isActive = false
    }

    // swiftlint:disable:next function_body_length
    func setUpFooterView() {
        view.addSubview(footerView)
        footerView.anchor(
            top: tabContainerView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )

        footerBottomToSafeConstraint = footerView.bottomAnchor.constraint(
            equalTo: view.safeBottomAnchor
        )
        footerBottomToSafeConstraint.isActive = true
        footerBottomToViewConstraint = footerView.bottomAnchor.constraint(
            equalTo: view.bottomAnchor
        )
        footerBottomToViewConstraint.isActive = false

        let sourceAndUpdateStack = UIStackView(
            arrangedSubviews: [
                dataSourceIconView,
                updatedAtLabel,
            ]
        )
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = Constants.Layout.sourceUpdateStackSpacing
        sourceAndUpdateStack.distribution = .fill

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(
                lessThanOrEqualToConstant: Constants.Layout.dataSourceIconMaxWidth
            )
        dataSourceIconViewWidthConstraint.isActive = true

        let footerStack = UIStackView(
            arrangedSubviews: [
                sourceAndUpdateStack,
                UIView.flexibleSpacer(),
                batteryLevelView,
            ]
        )
        footerStack.spacing = Constants.Layout.footerStackSpacing
        footerStack.axis = .horizontal
        footerStack.distribution = .fill

        footerView.addSubview(footerStack)
        footerStack
            .fillSuperview(
                padding: .init(
                    top: 0,
                    left: Constants.Layout.footerStackHorizontalPadding,
                    bottom: 0,
                    right: Constants.Layout.footerStackHorizontalPadding
                )
            )

        footerStackHeightConstraint = footerStack.heightAnchor.constraint(
            equalToConstant: Constants.Layout.footerStackHeight
        )
        footerStackHeightConstraint.isActive = true
        batteryLevelView.isHidden = true
    }

    private func embedChildViewControllers() {
        if AppUtility.isFoldableDevice {
            embedTabsInNativeTabBarController()
            return
        }
        for (tab, vc) in tabs {
            addChild(vc)
            vc.view.overrideUserInterfaceStyle = .dark
            tabContainerView.addSubview(vc.view)
            if tab == .measurement || tab == .graph {
                vc.view.fillSuperviewToSafeArea()
            } else if tab == .alerts || tab == .settings {
                vc.view.fillSuperview()
            }
            vc.didMove(toParent: self)
            vc.view.isHidden = tab != activeTab
        }
    }
}

// MARK: - iPhone Duo vertical bar
private extension CardsBaseViewController {
    func registerVerticalBarObserver() {
        guard #available(iOS 27.1, *) else { return }
        registerForTraitChanges(RuuviDuoLayout.traitsAffectingVerticalBar) {
            (controller: CardsBaseViewController, _: UITraitCollection) in
            controller.applyVerticalBarChrome(updateNavigationBarVisibility: true)
        }
    }

    /// iPhone Duo: where the system lays out bars vertically, back and the four tabs move into the
    /// navigation bar so they show in the vertical bar (Apple's pattern for iPhone Duo). The logo,
    /// sensor name row, tab content and footer stay as they are. `menuBarView` stays the single
    /// source of truth for the selected tab. On iPhone and iPad `isVerticalBarActive` is always
    /// false, so nothing here changes.
    func applyVerticalBarChrome(updateNavigationBarVisibility: Bool) {
        let shouldApply = RuuviDuoLayout.isVerticalBarActive(traitCollection)
        guard shouldApply != isVerticalBarChromeApplied else { return }
        isVerticalBarChromeApplied = shouldApply

        backButton.isHidden = shouldApply
        menuBarView.isHidden = shouldApply
        // Without the back button the logo would touch the edge: same inset as on the dashboard.
        headerWindowControlsInset?.baseConstant = shouldApply
            ? Constants.Layout.headerHorizontalPadding
            : 0

        if shouldApply {
            navigationItem.hidesBackButton = true
            navigationItem.leftBarButtonItems = [backBarItem]
            updateTabBarItemsSelection()
        } else {
            navigationItem.leftBarButtonItems = nil
            navigationItem.trailingItemGroups = []
            tabBarItems = [:]
            navigationItem.hidesBackButton = false
            // The tab row was hidden while the vertical bar showed the tabs: re-sync its marker.
            menuBarView.setSelectedTab(activeTab, animated: false, notify: false)
            menuBarView.setNeedsLayout()
        }
        updateNativeTabBarVisibility()

        if updateNavigationBarVisibility,
           viewIfLoaded?.window != nil,
           navigationController?.topViewController === self {
            navigationController?.setNavigationBarHidden(!shouldApply, animated: true)
        }
    }

    func makeTabBarItem(for tab: CardsMenuType) -> UIBarButtonItem {
        let title = tab.verticalBarTitle
        let image = tab.icon.ruuviBarIcon()
        let action = UIAction(title: title, image: image) { [weak self] _ in
            guard let self, tab != self.activeTab else { return }
            self.menuBarView.setSelectedTab(tab, animated: false, notify: false)
            self.handleTabChange(tab)
            if self.activeTab != tab {
                self.menuBarView.setSelectedTab(self.activeTab, animated: false, notify: false)
            }
        }
        let item = UIBarButtonItem(primaryAction: action)
        item.title = title
        item.image = image
        item.tintColor = .white
        if #available(iOS 27.0, *) {
            item.visibilityPriority = .high
        }
        return item
    }

    /// Shows the tabs in the vertical bar with the active one selected. The items are recreated on
    /// every change: the vertical bar doesn't redraw `isSelected` changes on items it already shows.
    func updateTabBarItemsSelection() {
        selectNativeTab(activeTab)
        guard isVerticalBarChromeApplied, !usesNativeTabBar else { return }
        var items: [CardsMenuType: UIBarButtonItem] = [:]
        for tab in CardsMenuType.allCases {
            let item = makeTabBarItem(for: tab)
            item.isSelected = tab == activeTab
            items[tab] = item
        }
        tabBarItems = items
        navigationItem.trailingItemGroups = [
            UIBarButtonItemGroup(
                barButtonItems: CardsMenuType.allCases.compactMap { items[$0] },
                representativeItem: nil
            ),
        ]
        updateAlertsBarItem(for: currentSnapshot)
    }

    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        menuBarView.updateAlertState(for: snapshot)
        updateAlertsBarItem(for: snapshot)
        updateNativeAlertsBadge(for: snapshot)
    }

    /// Mirrors the alert bell badge of `CardsMenuButton` on the vertical bar's alerts item.
    func updateAlertsBarItem(for snapshot: RuuviTagCardSnapshot?) {
        guard isVerticalBarChromeApplied, let item = tabBarItems[.alerts] else { return }
        item.isEnabled = snapshot != nil
        guard #available(iOS 26.0, *) else { return }
        guard let badgeData = snapshot?.alertBadgeData(), badgeData.count > 0 else {
            item.badge = nil
            return
        }
        var badge: UIBarButtonItem.Badge = badgeData.count > 99
            ? .string("99+")
            : .count(badgeData.count)
        badge.foregroundColor = .white
        badge.backgroundColor = badgeData.isTriggered ? RuuviColor.orangeColor.color : .clear
        item.badge = badge
    }
}

// MARK: - Size changes and the iPhone Duo native tab bar (the tab bar parts are no-ops on iPhone and iPad)
extension CardsBaseViewController {
    /// `spaceUntilSecondaryToolbar` from the current layout, without forcing a layout pass
    /// (read by the measurement details sheet on every height update, so it follows rotation,
    /// window resizing and iPhone Duo display changes).
    var currentSpaceUntilSecondaryToolbar: CGFloat {
        view.safeAreaInsets.top +
            headerContainerView.frame.height +
            secondaryToolbarView.frame.height +
            Constants.Layout.spaceUntilSecondaryToolbarExtraMargin
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        headerWindowControlsInset?.update()
        updateNativeTabBarLayout()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshNativeTabBarPlacement()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self else { return }
            if self.usesNativeTabBar {
                self.refreshNativeTabBarPlacement()
            }
            // The measurement details sheet caps its height by this screen's height (see
            // `MeasurementDetailsCoordinator`): let it measure again at the new size, also when
            // only the window's height changed and the sheet itself kept its size.
            self.presentedViewController?.viewIfLoaded?.setNeedsLayout()
        }
    }
}

private extension CardsBaseViewController {
    func embedTabsInNativeTabBarController() {
        let orderedTabs: [(CardsMenuType, UIViewController)] = CardsMenuType.allCases.compactMap { tab in
            guard let content = tabs[tab] else { return nil }
            content.view.overrideUserInterfaceStyle = .dark
            // Same pinning as in `embedChildViewControllers()`.
            let container = CardsNativeTabContainerViewController(
                content: content,
                extendsToBottomEdge: tab == .alerts || tab == .settings
            )
            return (tab, container)
        }
        for (index, (tab, container)) in orderedTabs.enumerated() {
            container.tabBarItem = UITabBarItem(
                title: tab.verticalBarTitle,
                image: tab.icon.ruuviBarIcon(),
                tag: index
            )
        }
        nativeTabContainers = Dictionary(uniqueKeysWithValues: orderedTabs)

        let tabBarController = UITabBarController()
        tabBarController.viewControllers = orderedTabs.map(\.1)
        tabBarController.selectedIndex = orderedTabs.firstIndex { $0.0 == activeTab } ?? 0
        tabBarController.delegate = self
        tabBarController.overrideUserInterfaceStyle = .dark
        tabBarController.view.backgroundColor = .clear
        tabBarController.tabBar.tintColor = .white

        // The tab bar controller spans the whole screen (behind the header, sensor row and footer):
        // the system only moves its tab bar into the vertical bar at the screen edge. The tab content
        // is kept in the tab container's region (see `updateNativeTabBarLayout()`).
        addChild(tabBarController)
        view.insertSubview(tabBarController.view, aboveSubview: tabBackgroundView)
        tabBarController.view.fillSuperview()
        tabBarController.didMove(toParent: self)
        nativeTabBarController = tabBarController
        // `tabContainerView` stays only as the layout reference for the tab content region; the tab
        // views now live in the tab bar controller underneath it, so it must not take their touches.
        tabContainerView.isUserInteractionEnabled = false
        updateNativeTabBarVisibility()
    }

    /// The native tab bar shows where the system lays out bars vertically; elsewhere (inner display
    /// in portrait) it is hidden and the custom tab row drives the tabs, as on iPhone.
    func updateNativeTabBarVisibility() {
        guard let tabBarController = nativeTabBarController else { return }
        let showsNativeTabBar = isVerticalBarChromeApplied
        if #available(iOS 18.0, *) {
            tabBarController.isTabBarHidden = !showsNativeTabBar
        } else {
            tabBarController.tabBar.isHidden = !showsNativeTabBar
        }
        menuBarView.isHidden = showsNativeTabBar
        if !showsNativeTabBar {
            menuBarView.setSelectedTab(activeTab, animated: false, notify: false)
            menuBarView.setNeedsLayout()
        }
        view.setNeedsLayout()
        if showsNativeTabBar {
            // The vertical bar settles after this pass (device opened, closed or rotated).
            DispatchQueue.main.async { [weak self] in
                self?.refreshNativeTabBarPlacement()
            }
        }
    }

    /// The system first draws the vertical tab bar at the wrong edge (bottom-leading) and only moves
    /// it into the shared vertical bar column (under Back, where UIKit lays it out and where the safe
    /// area already reserves room) on its next tab bar layout. Re-show it once the screen is on
    /// screen so it lands in the right place straight away.
    func refreshNativeTabBarPlacement() {
        guard let tabBarController = nativeTabBarController,
              isVerticalBarChromeApplied,
              view.window != nil else { return }
        if #available(iOS 18.0, *) {
            tabBarController.setTabBarHidden(true, animated: false)
            tabBarController.view.layoutIfNeeded()
            tabBarController.setTabBarHidden(false, animated: false)
        } else {
            tabBarController.tabBar.isHidden = true
            tabBarController.view.layoutIfNeeded()
            tabBarController.tabBar.isHidden = false
        }
    }

    func updateNativeTabBarLayout() {
        guard let tabBarController = nativeTabBarController else { return }

        // Keep the tab content in the tab container's region (below the sensor row, above the
        // footer) while the tab bar controller itself spans the screen.
        let safeArea = view.safeAreaInsets
        let insets = UIEdgeInsets(
            top: max(0, tabContainerView.frame.minY - safeArea.top),
            left: 0,
            bottom: max(0, view.bounds.height - safeArea.bottom - tabContainerView.frame.maxY),
            right: 0
        )
        if tabBarController.additionalSafeAreaInsets != insets {
            tabBarController.additionalSafeAreaInsets = insets
        }
    }

    func selectNativeTab(_ tab: CardsMenuType) {
        guard let tabBarController = nativeTabBarController,
              let viewController = nativeTabContainers[tab],
              tabBarController.selectedViewController !== viewController else { return }
        tabBarController.selectedViewController = viewController
    }

    /// Mirrors the alert bell badge of `CardsMenuButton` on the native alerts tab.
    func updateNativeAlertsBadge(for snapshot: RuuviTagCardSnapshot?) {
        guard usesNativeTabBar, let item = nativeTabContainers[.alerts]?.tabBarItem else { return }
        item.isEnabled = snapshot != nil
        guard let badgeData = snapshot?.alertBadgeData(), badgeData.count > 0 else {
            item.badgeValue = nil
            return
        }
        item.badgeValue = badgeData.count > 99 ? "99+" : "\(badgeData.count)"
        item.badgeColor = badgeData.isTriggered ? RuuviColor.orangeColor.color : .clear
        item.setBadgeTextAttributes([.foregroundColor: UIColor.white], for: .normal)
    }
}

/// iPhone Duo: hosts one tab of the native tab bar controller and gives it the frame the custom tab
/// container gave it: the safe area (which the card screen insets to the tab content region), and
/// for alerts and settings down to the bottom edge (their footer is hidden and they run to the
/// bottom of the screen).
private final class CardsNativeTabContainerViewController: UIViewController {
    private let content: UIViewController
    private let extendsToBottomEdge: Bool

    init(content: UIViewController, extendsToBottomEdge: Bool) {
        self.content = content
        self.extendsToBottomEdge = extendsToBottomEdge
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        addChild(content)
        view.addSubview(content.view)
        let safeArea = view.safeAreaLayoutGuide
        content.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            content.view.topAnchor.constraint(equalTo: safeArea.topAnchor),
            content.view.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor),
            content.view.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor),
            content.view.bottomAnchor.constraint(
                equalTo: extendsToBottomEdge ? view.bottomAnchor : safeArea.bottomAnchor
            ),
        ])
        content.didMove(toParent: self)
    }
}

extension CardsBaseViewController: UITabBarControllerDelegate {
    func tabBarController(
        _: UITabBarController,
        didSelect viewController: UIViewController
    ) {
        guard let tab = nativeTabContainers.first(where: { $0.value === viewController })?.key,
              tab != activeTab else { return }
        // Keep the (hidden) custom row in sync without it reporting the change a second time.
        menuBarView.setSelectedTab(tab, animated: false, notify: false)
        handleTabChange(tab)
        // The presenter switches synchronously, or shows a dialog first (keep connection, abort
        // sync). Until it does switch, keep the native tab bar and the row on the shown tab; its
        // later `showContentsForTab` selects the new tab.
        if activeTab != tab {
            menuBarView.setSelectedTab(activeTab, animated: false, notify: false)
            selectNativeTab(activeTab)
        }
    }
}

extension CardsMenuType {
    var verticalBarTitle: String {
        switch self {
        case .measurement:
            return RuuviDuoStrings.measurements
        case .graph:
            return RuuviDuoStrings.history
        case .alerts:
            return RuuviDuoStrings.alerts
        case .settings:
            return RuuviDuoStrings.settings
        }
    }
}

// MARK: Actions
private extension CardsBaseViewController {
    @objc func backButtonDidTap() {
        output?.viewDidTapBackButton()
    }

    @objc func cardLeftArrowButtonDidTap() {
        guard canNavigateLeft() else { return }
        let newIndex = currentSnapshotIndex - 1
        output?.viewDidRequestNavigateToSnapshotIndex(newIndex)
    }

    @objc func cardRightArrowButtonDidTap() {
        guard canNavigateRight() else { return }
        let newIndex = currentSnapshotIndex + 1
        output?.viewDidRequestNavigateToSnapshotIndex(newIndex)
    }

    func navigateFromSensorNameSwipe(
        _ direction: CardsSensorNameSwipeView.NavigationDirection
    ) -> Bool {
        let targetIndex: Int
        switch direction {
        case .previous:
            guard canNavigateLeft() else { return false }
            targetIndex = currentSnapshotIndex - 1
        case .next:
            guard canNavigateRight() else { return false }
            targetIndex = currentSnapshotIndex + 1
        }

        output?.viewDidRequestNavigateToSnapshotIndex(targetIndex)
        return currentSnapshotIndex == targetIndex
    }

    @objc func handleAppWillMoveToForeground() {
        output?.appWillMoveToForeground()
        updateAlertState(for: currentSnapshot)
    }
}

// MARK: - Private Helpers
private extension CardsBaseViewController {

    func startObservingAppState() {
        NotificationCenter
            .default
            .addObserver(
                self,
                selector: #selector(handleAppWillMoveToForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
    }

    func showTabViewController(for tab: CardsMenuType) {
        guard !usesNativeTabBar else {
            selectNativeTab(tab)
            return
        }
        guard let selectedVC = tabs[tab] else { return }

        UIView.animate(
            withDuration: Constants.Animation.tabTransitionDuration,
            delay: Constants.Animation.tabTransitionDelay,
            usingSpringWithDamping: Constants.Animation.tabTransitionDamping,
            initialSpringVelocity: Constants.Animation.tabTransitionVelocity,
            options: .curveEaseInOut,
            animations: {
            self.tabs.values.forEach { $0.view.alpha = 0 }
            selectedVC.view.alpha = 1
        }) { _ in
            self.tabs.forEach { (tabType, vc) in
                vc.view.isHidden = tabType != tab
                if tabType != tab {
                    vc.view.alpha = 1
                }
            }
        }
    }

    func handleTabChange(_ tab: CardsMenuType) {
        output?.viewDidChangeTab(tab)
    }

    func updateHeaderSubtitle(for tab: CardsMenuType, animated: Bool = false) {
        let subtitle = headerSubtitle(for: tab)
        let shouldShowSubtitle = subtitle != nil

        guard animated, view.window != nil else {
            UIView.performWithoutAnimation {
                self.pageTitleLabel.text = subtitle
                self.pageTitleLabel.alpha = shouldShowSubtitle ? 1 : 0
                self.pageTitleLabel.isHidden = !shouldShowSubtitle
                self.view.layoutIfNeeded()
            }
            return
        }

        view.layoutIfNeeded()

        if shouldShowSubtitle {
            self.pageTitleLabel.text = subtitle
            self.pageTitleLabel.alpha = 0
            self.pageTitleLabel.isHidden = false
        } else {
            self.pageTitleLabel.alpha = 0
            self.pageTitleLabel.isHidden = true
        }

        UIView.animate(
            withDuration: Constants.Animation.tabTransitionDuration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.pageTitleLabel.alpha = shouldShowSubtitle ? 1 : 0
                self.view.layoutIfNeeded()
            }
        )
    }

    func headerSubtitle(for tab: CardsMenuType) -> String? {
        switch tab {
        case .alerts:
            return RuuviLocalization.TagSettings.Label.Alerts.text
        case .settings:
            return RuuviLocalization.Settings.NavigationItem.title
        case .measurement, .graph:
            return nil
        }
    }

    // MARK: - Navigation Helpers
    func canNavigateLeft() -> Bool {
        return currentSnapshotIndex > 0
    }

    func canNavigateRight() -> Bool {
        return currentSnapshotIndex < currentSnapshots.count - 1
    }

    func updateCurrentSnapshotUI() {
        guard currentSnapshotIndex < currentSnapshots.count else {
            return
        }

        guard !isUpdatingUI else {
            return
        }
        isUpdatingUI = true
        defer { isUpdatingUI = false }

        let currentSnapshot = currentSnapshots[currentSnapshotIndex]
        self.currentSnapshot = currentSnapshot
        updateAlertState(for: currentSnapshot)
        cardBackgroundView
            .setBackgroundImage(
                with: currentSnapshot.displayData.background,
                isDashboard: false,
                withAnimation: true
            )

        updateSensorNameSwipeView()
        updateHeaderSubtitle(for: activeTab)

        updateNavigationButtonsVisibility()
        updateFooter()
    }

    func updateNavigationButtonsVisibility() {
        let showLeftArrow = canNavigateLeft()
        let showRightArrow = canNavigateRight()
        cardLeftArrowButton.isHidden = !showLeftArrow
        cardRightArrowButton.isHidden = !showRightArrow
    }

    func updateSensorNameSwipeView() {
        guard currentSnapshots.indices.contains(currentSnapshotIndex) else { return }

        let previousName = currentSnapshotIndex > 0 ?
            currentSnapshots[currentSnapshotIndex - 1].displayData.name : nil
        let nextName = currentSnapshotIndex < currentSnapshots.count - 1 ?
            currentSnapshots[currentSnapshotIndex + 1].displayData.name : nil
        sensorNameSwipeView.configure(
            current: currentSnapshots[currentSnapshotIndex].displayData.name,
            previous: previousName,
            next: nextName
        )
    }

    // MARK: - Footer Update Methods
    private func updateFooter() {
        guard currentSnapshotIndex < currentSnapshots.count else {
            updateFooterVisibility(for: activeTab, animated: false)
            return
        }

        let currentSnapshot = currentSnapshots[currentSnapshotIndex]

        updateSourceIcon(for: currentSnapshot.displayData.source)
        batteryLevelView.isHidden = !currentSnapshot.displayData.batteryNeedsReplacement
        updateTimestampLabel()
        updateFooterVisibility(for: activeTab, animated: false)
    }

    func updateFooterVisibility(
        for tab: CardsMenuType,
        animated: Bool
    ) {
        guard isViewLoaded else { return }
        guard footerStackHeightConstraint != nil,
              tabContainerBottomToViewConstraint != nil,
              footerBottomToViewConstraint != nil,
              footerBottomToSafeConstraint != nil else {
            return
        }
        let hasSnapshot = currentSnapshotIndex < currentSnapshots.count
        let shouldExtendToBottom = tab == .alerts || tab == .settings
        applyFooterBottomLayout(extendToBottom: shouldExtendToBottom)

        let shouldCollapse = !hasSnapshot || tab == .alerts || tab == .settings
        let targetAlpha: CGFloat = shouldCollapse ? 0 : 1
        footerStackHeightConstraint.constant = shouldCollapse ? 0 : Constants.Layout.footerStackHeight
        footerView.isUserInteractionEnabled = !shouldCollapse
        footerView.isHidden = !hasSnapshot

        if animated && view.window != nil {
            UIView.animate(
                withDuration: Constants.Animation.tabTransitionDuration,
                delay: 0,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    self.footerView.alpha = targetAlpha
                    self.applyFooterLayoutIfNeeded()
                }
            )
        } else {
            footerView.alpha = targetAlpha
            applyFooterLayoutIfNeeded()
        }
    }

    private func applyFooterBottomLayout(extendToBottom: Bool) {
        // Deactivate incompatible constraints first to avoid transient invalid states.
        if extendToBottom {
            footerBottomToSafeConstraint.isActive = false
            tabContainerBottomToViewConstraint.isActive = true
            footerBottomToViewConstraint.isActive = true
        } else {
            tabContainerBottomToViewConstraint.isActive = false
            footerBottomToViewConstraint.isActive = false
            footerBottomToSafeConstraint.isActive = true
        }
    }

    private func applyFooterLayoutIfNeeded() {
        // Avoid forcing an immediate layout pass while the VC is off-screen.
        if view.window != nil {
            view.layoutIfNeeded()
        } else {
            view.setNeedsLayout()
        }
    }

    private func updateSourceIcon(for source: RuuviTagSensorRecordSource?) {
        guard let source = source else {
            dataSourceIconView.image = nil
            return
        }

        switch source {
        case .unknown:
            dataSourceIconView.image = nil
        case .advertisement, .bgAdvertisement:
            dataSourceIconView.image = RuuviAsset.iconBluetooth.image
        case .heartbeat, .log:
            dataSourceIconView.image = RuuviAsset.iconBluetoothConnected.image
        case .ruuviNetwork:
            dataSourceIconView.image = RuuviAsset.iconGateway.image
        }

        dataSourceIconView.image = dataSourceIconView.image?
            .withRenderingMode(.alwaysTemplate)
    }

    func reconfigureSnapshotObservation() {
        cancellables.removeAll()

        guard let currentSnapshot else { return }

        currentSnapshot.$displayData
            .receive(on: DispatchQueue.main)
            .sink { [weak self] displayData in
                if displayData.name != self?.sensorNameSwipeView.text {
                    self?.updateSensorNameSwipeView()
                }

                if displayData.background !=
                    self?.cardBackgroundView.backgroundImage() {
                    self?.cardBackgroundView.setBackgroundImage(
                        with: displayData.background,
                        isDashboard: false,
                        withAnimation: true
                    )
                }
            }
            .store(in: &cancellables)

        currentSnapshot.$alertData
            .sink { [weak self] _ in
                self?.updateAlertState(for: currentSnapshot)
            }
            .store(in: &cancellables)

        currentSnapshot.$metadata
            .sink { [weak self] _ in
                self?.updateAlertState(for: currentSnapshot)
            }
            .store(in: &cancellables)
    }
}

// MARK: - TimestampUpdateable
extension CardsBaseViewController: TimestampUpdateable {
    func updateTimestampLabel() {
        guard currentSnapshotIndex < currentSnapshots.count else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
            return
        }

        let currentSnapshot = currentSnapshots[currentSnapshotIndex]
        if let date = currentSnapshot.lastUpdated {
            updatedAtLabel.text = date.ruuviAgo()
        } else {
            updatedAtLabel.text = RuuviLocalization.Cards.UpdatedLabel.NoData.message
        }
    }
}

// MARK: - MeasurementDetailsCoordinatorDelegate
extension CardsBaseViewController: MeasurementDetailsCoordinatorDelegate {
    func measurementDetailsCoordinatorDidDismiss(
        _ coordinator: MeasurementDetailsCoordinator
    ) {
        detailsCoordinator?.stop()
        detailsCoordinator = nil
    }

    func measurementDetailsCoordinatorDidDismissWithGraphTap(
        for snapshot: RuuviTagCardSnapshot,
        measurement: MeasurementType,
        variant: MeasurementDisplayVariant?,
        ruuviTag: RuuviTagSensor,
        _ coordinator: MeasurementDetailsCoordinator
    ) {
        detailsCoordinator?.stop()
        detailsCoordinator = nil
        output?.viewDidScrollToGraph(for: measurement, variant: variant)
        activeTab = .graph
        menuBarView.setSelectedTab(.graph, animated: true, notify: false)
        if !usesNativeTabBar {
            updateTabBarItemsSelection()
        }
    }
}

// MARK: - CardsBaseViewInput
extension CardsBaseViewController: CardsBaseViewInput {
    func setActiveTab(_ tab: CardsMenuType) {
        handleTabChange(tab)
    }

    func showContentsForTab(_ tab: CardsMenuType) {
        updateTabBackground(for: tab, animated: true)
        showTabViewController(for: tab)
        activeTab = tab
        updateHeaderSubtitle(for: tab, animated: true)
        menuBarView.setSelectedTab(tab, animated: true)
        updateTabBarItemsSelection()
        updateFooterVisibility(for: tab, animated: true)
    }

    func setSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        currentSnapshots = snapshots
    }

    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot) {
        if let snapshotIndex = currentSnapshots.firstIndex(where: { $0.id == snapshot.id }) {
            currentSnapshots[snapshotIndex] = snapshot
            updateCurrentSnapshotUI()
        }
    }

    func setActiveSnapshotIndex(_ index: Int) {
        currentSnapshotIndex = index
        updateCurrentSnapshotUI()
    }

    func setActivityIndicatorVisible(_ visible: Bool) {
        if visible {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        // The simulator has no Bluetooth: don't show this alert on every launch there.
        guard !UIDevice.isSimulator else { return }
        let title = RuuviLocalization.Cards.BluetoothDisabledAlert.title
        let message = RuuviLocalization.Cards.BluetoothDisabledAlert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.PermissionPresenter.settings,
            style: .default,
            handler: { _ in
                guard let url = URL(string: userDeclined ?
                    UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
                    UIApplication.shared.canOpenURL(url)
                else {
                    return
                }
                UIApplication.shared.open(url)
            }
        ))
        alertVC
            .addAction(
                UIAlertAction(
                    title: RuuviLocalization.ok,
                    style: .cancel,
                    handler: nil
                )
        )
        present(alertVC, animated: true)
    }

    func showKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output?.viewDidDismissKeepConnectionDialogChart(for: snapshot)
        }))
        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output?.viewDidConfirmToKeepConnectionChart(to: snapshot)
        }))
        present(alert, animated: true)
    }

    func showKeepConnectionDialogSettings(for snapshot: RuuviTagCardSnapshot) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output?.viewDidDismissKeepConnectionDialogSettings(for: snapshot)
        }))
        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output?.viewDidConfirmToKeepConnectionSettings(to: snapshot)
        }))
        present(alert, animated: true)
    }

    func showFirmwareUpdateDialog(for snapshot: RuuviTagCardSnapshot) {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output?.viewDidIgnoreFirmwareUpdateDialog(for: snapshot)
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output?.viewDidConfirmFirmwareUpdate(for: snapshot)
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog(for snapshot: RuuviTagCardSnapshot) {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output?.viewDidDismissFirmwareUpdateDialog(for: snapshot)
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output?.viewDidConfirmFirmwareUpdate(for: snapshot)
        }))
        present(alert, animated: true)
    }

    func showMeasurementDetails(
        for indicator: RuuviTagCardSnapshotIndicatorData,
        snapshot: RuuviTagCardSnapshot,
        sensor: RuuviTagSensor,
        settings: SensorSettings?
    ) {
        detailsCoordinator = MeasurementDetailsCoordinator(
            baseViewController: self,
            for: indicator,
            snapshot: snapshot,
            ruuviTagSensor: sensor,
            sensorSetting: settings,
            delegate: self
        )
        detailsCoordinator?.start()
    }
}

// MARK: - Tab Background
private extension CardsBaseViewController {
    func updateTabBackground(for tab: CardsMenuType, animated: Bool) {
        let targetColor = tabBackgroundColor(for: tab)
        if animated {
            UIView.animate(
                withDuration: Constants.Animation.chartBackgroundTransitionDuration
            ) { [weak self] in
                self?.tabBackgroundView.backgroundColor = targetColor
            }
        } else {
            tabBackgroundView.backgroundColor = targetColor
        }
    }

    func tabBackgroundColor(for tab: CardsMenuType) -> UIColor {
        switch tab {
        case .measurement:
            return .clear
        case .graph:
            return RuuviColor.graphBGColor.color
        case  .alerts, .settings:
            return RuuviColor.ruuviGreen.color.withAlphaComponent(0.7)
        }
    }
}

// swiftlint:enable file_length
