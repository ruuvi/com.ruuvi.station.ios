import UIKit
import RuuviLocalization
import RuuviOntology

class NewCardsLandingViewController: UIViewController, CardsLandingViewInput, TimestampUpdateable {

    // MARK: - Properties
    var output: CardsLandingViewOutput?

    // MARK: - Tab Management
    private var tabViewControllers: [CardsMenuType: UIViewController] = [:]
    private var currentTabViewController: UIViewController?

    // MARK: - Base UI Components
    private lazy var cardBackgroundView = CardsBackgroundView()
    private lazy var chartViewBackground = UIView(color: RuuviColor.graphBGColor.color)

    // Header
    private lazy var headerView = UIView(color: .clear)

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
    private lazy var backButtonView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear

        let iv = UIImageView(image: RuuviAsset.chevronBack.image)
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = .white
        view.addSubview(iv)
        iv.fillSuperview(padding: .init(top: 10, left: 8, bottom: 10, right: 0))

        view.addSubview(backButton)
        backButton.fillSuperview()

        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        return ai
    }()

    private lazy var menuBarView: CardsMenuBarViewController = {
        let vc = CardsMenuBarViewController()
        vc.view.backgroundColor = .clear
        return vc
    }()

    // Secondary Toolbar
    private lazy var secondaryToolbarView = UIView(color: .clear)
    private lazy var cardLeftArrowButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "chevron.left")
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
            icon: UIImage(systemName: "chevron.right")
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
        label.text = ""
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.font = UIFont.Muli(.extraBold, size: 20)
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
        let view = BatteryLevelView(
            fontSize: 10,
            iconSize: 16
        )
        view.updateTextColor(with: .white.withAlphaComponent(0.8))
        return view
    }()

    private lazy var updatedAtLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white.withAlphaComponent(0.8)
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.Muli(.regular, size: 10)
        return label
    }()

    private lazy var dataSourceIconView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.alpha = 0.7
        iv.tintColor = .white.withAlphaComponent(0.8)
        return iv
    }()

    private var dataSourceIconViewWidthConstraint: NSLayoutConstraint!

    // MARK: - State
    private var currentSnapshots: [RuuviTagCardSnapshot] = []
    private var currentSnapshotIndex: Int = 0

    // MARK: - FIXED: Background State Tracking
    private var currentBackgroundImage: UIImage?
    private var isInitialLoad = true
    private var lastUpdatedSnapshotId: String?
    private var isUpdatingUI = false

    // FIXED: Track background image per snapshot ID to detect changes
    private var snapshotBackgroundMap: [String: UIImage?] = [:]

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        setupTabContainer()
        setupFooter()
        TimestampUpdateService.shared.addSubscriber(self)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.viewDidLoad()
        output?.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output?.viewWillDisappear()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            TimestampUpdateService.shared.removeSubscriber(self)
        }
    }

    deinit {
        TimestampUpdateService.shared.removeSubscriber(self)
    }

    // MARK: - Tab View Controller Setup
    func setupTabViewControllers(_ controllers: [CardsMenuType: UIViewController]) {
        tabViewControllers = controllers

        let initialTab = menuBarView.getCurrentTab()
        showTabViewController(for: initialTab)
    }

    // FIXED: Force background refresh method for external updates
    func forceBackgroundRefresh() {
        guard currentSnapshotIndex < currentSnapshots.count else { return }

        let currentSnapshot = currentSnapshots[currentSnapshotIndex]
        print("forceBackgroundRefresh - Forcing refresh for snapshot: \(currentSnapshot.id)")

        // Clear the tracking to force update
        snapshotBackgroundMap[currentSnapshot.id] = nil
        currentBackgroundImage = nil

        // Update with the current background
        updateBackgroundIfNeeded(currentSnapshot.displayData.background, snapshotId: currentSnapshot.id)
    }

    // MARK: - Footer Setup
    private func setupFooter() {
        let sourceAndUpdateStack = UIStackView(
            arrangedSubviews: [
                dataSourceIconView,
                updatedAtLabel,
            ]
        )
        sourceAndUpdateStack.axis = .horizontal
        sourceAndUpdateStack.spacing = 6
        sourceAndUpdateStack.distribution = .fill

        dataSourceIconViewWidthConstraint = dataSourceIconView.widthAnchor
            .constraint(lessThanOrEqualToConstant: 22)
        dataSourceIconViewWidthConstraint.isActive = true

        let footerStack = UIStackView(
            arrangedSubviews: [
                sourceAndUpdateStack,
                UIView.flexibleSpacer(),
                batteryLevelView,
            ]
        )
        footerStack.spacing = 4
        footerStack.axis = .horizontal
        footerStack.distribution = .fill

        footerView.addSubview(footerStack)
        footerStack.fillSuperview(padding: .init(top: 0, left: 20, bottom: 0, right: 20))

        footerStack.constrainHeight(constant: 24)
        batteryLevelView.isHidden = true
    }

    // MARK: - Footer Update Methods
    private func updateFooter() {
        guard currentSnapshotIndex < currentSnapshots.count else {
            footerView.isHidden = true
            return
        }

        let currentSnapshot = currentSnapshots[currentSnapshotIndex]
        footerView.isHidden = false

        updateSourceIcon(for: currentSnapshot.displayData.source)
        batteryLevelView.isHidden = !currentSnapshot.displayData.batteryNeedsReplacement
        updateTimestampLabel()
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

// MARK: - UI Setup
private extension NewCardsLandingViewController {
    func setUpUI() {
        setUpBaseView()
        setUpHeaderView()
        setUpSecondaryToolbarView()
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.primary.color

        view.addSubview(cardBackgroundView)
        cardBackgroundView.fillSuperview()

        view.addSubview(chartViewBackground)
        chartViewBackground.fillSuperview()
        chartViewBackground.alpha = 0
    }

    func setUpHeaderView() {
        view.addSubview(headerView)
        headerView
            .anchor(
                top: view.safeTopAnchor,
                leading: view.safeLeftAnchor,
                bottom: nil,
                trailing: view.safeRightAnchor,
                size: .init(width: 0, height: 40)
            )

        headerView.addSubview(backButtonView)
        backButtonView.anchor(
            top: headerView.topAnchor,
            leading: headerView.leadingAnchor,
            bottom: headerView.bottomAnchor,
            trailing: nil,
            size: .init(width: 40, height: 40)
        )

        headerView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: backButton.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 20, bottom: 0, right: 0),
            size: .init(width: 90, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        headerView.addSubview(activityIndicator)
        activityIndicator.centerInSuperview()

        addChild(menuBarView)
        headerView.addSubview(menuBarView.view)
        menuBarView.didMove(toParent: self)
        menuBarView.view
            .anchor(
                top: headerView.topAnchor,
                leading: nil,
                bottom: headerView.bottomAnchor,
                trailing: headerView.trailingAnchor,
                padding: .init(top: 0, left: 0, bottom: 0, right: 10)
            )
        menuBarView.onTabChanged = { [weak self] tab in
            self?.handleTabChange(tab)
        }
    }

    func setUpSecondaryToolbarView() {
        view.addSubview(secondaryToolbarView)
        secondaryToolbarView.anchor(
            top: headerView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(top: 2, left: 0, bottom: 0, right: 0)
        )

        secondaryToolbarView.addSubview(cardLeftArrowButton)
        cardLeftArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: secondaryToolbarView.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 6, left: 4, bottom: 0, right: 0)
        )

        secondaryToolbarView.addSubview(cardRightArrowButton)
        cardRightArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: secondaryToolbarView.trailingAnchor,
            padding: .init(top: 6, left: 0, bottom: 0, right: 4)
        )

        secondaryToolbarView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: cardLeftArrowButton.trailingAnchor,
            bottom: secondaryToolbarView.bottomAnchor,
            trailing: cardRightArrowButton.leadingAnchor,
            padding: .init(top: 8, left: 4, bottom: 6, right: 4)
        )
    }

    func setupTabContainer() {
        view.addSubview(tabContainerView)
        view.addSubview(footerView)

        tabContainerView.anchor(
            top: secondaryToolbarView.bottomAnchor,
            leading: view.leadingAnchor,
            bottom: footerView.topAnchor,
            trailing: view.trailingAnchor,
            padding: .init(top: 8, left: 0, bottom: 8, right: 0)
        )

        footerView.anchor(
            top: nil,
            leading: view.leadingAnchor,
            bottom: view.safeAreaLayoutGuide.bottomAnchor,
            trailing: view.trailingAnchor
        )
    }

    func createTabViewControllers() {
        tabViewControllers[.measurement] = CardsMeasurementViewController()
        tabViewControllers[.graph] = CardsGraphViewController()
        tabViewControllers[.alerts] = CardsAlertsViewController()
        tabViewControllers[.settings] = CardsSettingsViewController()
    }
}

// MARK: - Tab Management
private extension NewCardsLandingViewController {
    func showTabViewController(for tab: CardsMenuType) {
        if let currentVC = currentTabViewController {
            currentVC.willMove(toParent: nil)
            currentVC.view.removeFromSuperview()
            currentVC.removeFromParent()
        }

        guard let newTabVC = tabViewControllers[tab] else { return }

        addChild(newTabVC)
        tabContainerView.addSubview(newTabVC.view)
        newTabVC.view.fillSuperview()
        newTabVC.didMove(toParent: self)

        currentTabViewController = newTabVC
        output?.viewDidChangeTab(tab)
    }

    func handleTabChange(_ tab: CardsMenuType) {
        showTabViewController(for: tab)
        menuBarView.setSelectedTab(tab, animated: true)
    }
}

// MARK: - Snapshot Navigation
private extension NewCardsLandingViewController {
    @objc func cardLeftArrowButtonDidTap() {
        guard currentSnapshotIndex > 0 else { return }
        let newIndex = currentSnapshotIndex - 1
        output?.viewDidNavigateToSnapshot(at: newIndex)
    }

    @objc func cardRightArrowButtonDidTap() {
        guard currentSnapshotIndex < currentSnapshots.count - 1 else { return }
        let newIndex = currentSnapshotIndex + 1
        output?.viewDidNavigateToSnapshot(at: newIndex)
    }

    func updateCurrentSnapshotUI() {
        guard currentSnapshotIndex < currentSnapshots.count else {
            print("updateCurrentSnapshotUI - Invalid index: \(currentSnapshotIndex), count: \(currentSnapshots.count)")
            return
        }

        guard !isUpdatingUI else {
            print("updateCurrentSnapshotUI - Already updating, skipping")
            return
        }
        isUpdatingUI = true
        defer { isUpdatingUI = false }

        let currentSnapshot = currentSnapshots[currentSnapshotIndex]
        let currentSnapshotId = currentSnapshot.id
        let isNewSnapshot = lastUpdatedSnapshotId != currentSnapshotId
        lastUpdatedSnapshotId = currentSnapshotId

        // FIXED: Always check for background changes, not just new snapshots
        updateBackgroundIfNeeded(currentSnapshot.displayData.background, snapshotId: currentSnapshotId)

        ruuviTagNameLabel.text = currentSnapshot.displayData.name

        let showLeftArrow = currentSnapshotIndex > 0
        let showRightArrow = currentSnapshotIndex < currentSnapshots.count - 1
        cardLeftArrowButton.isHidden = !showLeftArrow
        cardRightArrowButton.isHidden = !showRightArrow

        updateFooter()
    }

    // FIXED: Enhanced background update detection
    private func updateBackgroundIfNeeded(_ newBackgroundImage: UIImage?, snapshotId: String) {
        // Check if background changed for this specific snapshot
        let previousBackground = snapshotBackgroundMap[snapshotId]
        let backgroundChanged = (previousBackground != newBackgroundImage)

        // Also check if this is a different snapshot with different background
        let globalBackgroundChanged = (currentBackgroundImage !== newBackgroundImage)

        print("updateBackgroundIfNeeded - SnapshotID: \(snapshotId)")
        print("  Previous: \(previousBackground != nil ? "present" : "nil")")
        print("  New: \(newBackgroundImage != nil ? "present" : "nil")")
        print("  Background changed for snapshot: \(backgroundChanged)")
        print("  Global background changed: \(globalBackgroundChanged)")

        guard backgroundChanged || globalBackgroundChanged else {
            print("  No background change detected, skipping update")
            return
        }

        // Update tracking
        snapshotBackgroundMap[snapshotId] = newBackgroundImage
        currentBackgroundImage = newBackgroundImage

        let shouldAnimate = !isInitialLoad
        isInitialLoad = false

        print("  Updating background with animation: \(shouldAnimate)")

        cardBackgroundView.setBackgroundImage(
            with: newBackgroundImage,
            isDashboard: false,
            withAnimation: shouldAnimate
        )
    }
}

// MARK: - Actions
private extension NewCardsLandingViewController {
    @objc func backButtonDidTap() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.popViewController(animated: true)
    }

    @objc func refreshButtonDidTap() {
        output?.viewDidTriggerRefresh()
    }
}

// MARK: - CardsLandingViewInput
extension NewCardsLandingViewController {
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
        let snapshotsChanged = currentSnapshots.count != snapshots.count ||
                              !currentSnapshots.elementsEqual(snapshots, by: { $0.id == $1.id })

        // FIXED: Always update snapshots and check for background changes
        let oldSnapshots = currentSnapshots
        currentSnapshots = snapshots

        // Check if current snapshot's background changed
        if !snapshotsChanged && currentSnapshotIndex < snapshots.count {
            let currentSnapshot = snapshots[currentSnapshotIndex]
            let oldSnapshot = currentSnapshotIndex < oldSnapshots.count ? oldSnapshots[currentSnapshotIndex] : nil

            if let oldSnapshot = oldSnapshot,
               oldSnapshot.id == currentSnapshot.id,
               oldSnapshot.displayData.background !== currentSnapshot.displayData.background {
                print("updateSnapshots - Background changed for current snapshot: \(currentSnapshot.id)")
                forceBackgroundRefresh()
                return
            }
        }

        if snapshotsChanged {
            print("updateSnapshots - Count: \(snapshots.count), Index: \(currentSnapshotIndex)")
        }

        updateCurrentSnapshotUI()
    }

    func updateCurrentSnapshotIndex(_ index: Int) {
        guard index != currentSnapshotIndex else { return }

        print("updateCurrentSnapshotIndex - Old: \(currentSnapshotIndex), New: \(index)")
        currentSnapshotIndex = index
        updateCurrentSnapshotUI()
    }

    func updateCurrentTab(_ tab: CardsMenuType) {
        if menuBarView.getCurrentTab() != tab {
            menuBarView.setSelectedTab(tab, animated: true)
        }
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = "Bluetooth Required"
        let message = userDeclined
            ? "Please enable Bluetooth in Settings to connect to your sensors."
            : "Please turn on Bluetooth to connect to your sensors."

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        if userDeclined {
            alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            })
        }

        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        present(alert, animated: true)
    }

    func showError(_ error: Error) {
        let alert = UIAlertController(
            title: "Error",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    func showLoading() {
        activityIndicator.startAnimating()
        ruuviTagNameLabel.text = "Loading..."
        footerView.isHidden = true
    }

    func hideLoading() {
        activityIndicator.stopAnimating()
        if !currentSnapshots.isEmpty {
            updateCurrentSnapshotUI()
        }
    }
}

// MARK: - Common Dialog Handling
extension NewCardsLandingViewController {

    func showKeepConnectionDialog(
        for sensorName: String,
        completion: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(
            title: "Keep Connection",
            message: "Do you want to keep the connection to \(sensorName) active?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "No", style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: "Yes", style: .default) { _ in
            completion(true)
        })

        present(alert, animated: true)
    }

    func showFirmwareUpdateDialog(
        for sensorName: String,
        completion: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(
            title: "Firmware Update",
            message: "A firmware update is available for \(sensorName). Would you like to update?",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "Later", style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: "Update", style: .default) { _ in
            completion(true)
        })

        present(alert, animated: true)
    }

    func showConfirmationDialog(
        title: String,
        message: String,
        confirmTitle: String = "Confirm",
        cancelTitle: String = "Cancel",
        completion: @escaping (Bool) -> Void
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: cancelTitle, style: .cancel) { _ in
            completion(false)
        })

        alert.addAction(UIAlertAction(title: confirmTitle, style: .default) { _ in
            completion(true)
        })

        present(alert, animated: true)
    }

    func showInfoDialog(title: String, message: String) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
