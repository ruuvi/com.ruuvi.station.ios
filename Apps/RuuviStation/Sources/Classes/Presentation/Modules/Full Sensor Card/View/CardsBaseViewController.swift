// swiftlint:disable file_length

import RuuviLocalization
import UIKit
import RuuviLocal
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
            static let secondaryToolbarTopPadding: CGFloat = 2
            static let arrowButtonTopPadding: CGFloat = 6
            static let arrowButtonSidePadding: CGFloat = 4
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
            static let batteryLabelFontSize: CGFloat = 10
            static let batteryIconSize: CGFloat = 16
            static let updatedAtLabelFontSize: CGFloat = 10
            static let tagNameLabelLines: Int = 2
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

    // MARK: Depenencies
    private let flags: RuuviLocalFlags

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
        let view = CardsMenuBarView(
            menuMode: flags.showNewCardsMenu ? .modern : .legacy
        )
        view.setSelectedTab(activeTab, notify: false)
        view.backgroundColor = .clear
        return view
    }()

    // Secondary Toolbar
    private lazy var secondaryToolbarView = UIView(color: .clear)
    private lazy var cardLeftArrowButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "chevron.left"),
            leadingPadding: 10
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
            trailingPadding: 10
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

    lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = Constants.Typography.tagNameLabelLines
        label.font = UIFont
            .mulish(
                .extraBold,
                size: Constants.Typography.tagNameLabelFontSize
            )
        label.setContentHuggingPriority(.required, for: .vertical)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }()

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
        activeTab: CardsMenuType,
        flags: RuuviLocalFlags
    ) {
        self.tabs = tabs
        self.activeTab = activeTab
        self.flags = flags
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        startObservingAppState()
        TimestampUpdateService.shared.addSubscriber(self)
        updateCurrentSnapshotUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
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

        ruuviLogoView.widthAnchor.constraint(equalToConstant: Constants.Layout.ruuviLogoSize.width).isActive = true
        ruuviLogoView.heightAnchor.constraint(equalToConstant: Constants.Layout.ruuviLogoSize.height).isActive = true

        headerContainerView.addSubview(headerLeadingStack)
        headerLeadingStack
            .anchor(
                top: headerContainerView.topAnchor,
                leading: headerContainerView.safeLeftAnchor,
                bottom: headerContainerView.bottomAnchor,
                trailing: nil
            )

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
        activityIndicator.centerInSuperview()

        menuBarView.onTabChanged = { [weak self] tab in
            self?.handleTabChange(tab)
        }
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
            bottom: nil,
            trailing: nil,
            padding: .init(
                top: Constants.Layout.arrowButtonTopPadding,
                left: Constants.Layout.arrowButtonSidePadding,
                bottom: 0,
                right: 0
            )
        )

        secondaryToolbarView.addSubview(cardRightArrowButton)
        cardRightArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: secondaryToolbarView.trailingAnchor,
            padding: .init(
                top: Constants.Layout.arrowButtonTopPadding,
                left: 0,
                bottom: 0,
                right: Constants.Layout.arrowButtonSidePadding
            )
        )

        secondaryToolbarView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: cardLeftArrowButton.trailingAnchor,
            bottom: secondaryToolbarView.bottomAnchor,
            trailing: cardRightArrowButton.leadingAnchor,
            padding: Constants.Layout.tagNameLabelPadding
        )
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
        if flags.showNewCardsMenu {
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
        } else {
            for (tab, vc) in tabs {
                if tab == .settings { continue }
                addChild(vc)
                vc.view.overrideUserInterfaceStyle = .unspecified
                tabContainerView.addSubview(vc.view)
                vc.view.fillSuperviewToSafeArea()
                vc.didMove(toParent: self)
                vc.view.isHidden = tab != activeTab
            }
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

    @objc func handleAppWillMoveToForeground() {
        output?.appWillMoveToForeground()
        menuBarView.updateAlertState(for: currentSnapshot)
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
        menuBarView.updateAlertState(for: currentSnapshot)
        cardBackgroundView
            .setBackgroundImage(
                with: currentSnapshot.displayData.background,
                isDashboard: false,
                withAnimation: true
            )

        ruuviTagNameLabel.text = currentSnapshot.displayData.name

        updateNavigationButtonsVisibility()
        updateFooter()
    }

    func updateNavigationButtonsVisibility() {
        let showLeftArrow = canNavigateLeft()
        let showRightArrow = canNavigateRight()
        cardLeftArrowButton.isHidden = !showLeftArrow
        cardRightArrowButton.isHidden = !showRightArrow
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
        guard flags.showNewCardsMenu else {
            footerView.isHidden = !hasSnapshot
            footerView.alpha = 1
            footerStackHeightConstraint.constant = Constants.Layout.footerStackHeight
            applyFooterBottomLayout(extendToBottom: false)
            applyFooterLayoutIfNeeded()
            return
        }

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
                if displayData.name != self?.ruuviTagNameLabel.text {
                    self?.ruuviTagNameLabel.text = displayData.name
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
                self?.menuBarView.updateAlertState(for: currentSnapshot)
            }
            .store(in: &cancellables)

        currentSnapshot.$metadata
            .sink { [weak self] _ in
                self?.menuBarView.updateAlertState(for: currentSnapshot)
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
    }
}

// MARK: - CardsBaseViewInput
extension CardsBaseViewController: CardsBaseViewInput {
    func setActiveTab(_ tab: CardsMenuType) {
        handleTabChange(tab)
    }

    func showContentsForTab(_ tab: CardsMenuType) {
        if flags.showNewCardsMenu {
            updateTabBackground(for: tab, animated: true)
            showTabViewController(for: tab)
            activeTab = tab
            menuBarView.setSelectedTab(tab, animated: true)
            updateFooterVisibility(for: tab, animated: true)
        } else {
            switch tab {
            case .measurement, .graph:
                updateTabBackground(for: tab, animated: true)
                showTabViewController(for: tab)
                activeTab = tab
            default:
                break
            }
        }
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
