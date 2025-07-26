import RuuviLocalization
import UIKit
import RuuviLocal

/// Base view controller that manages multiple tab view controllers
final class NewCardsBaseViewController: UIViewController {

    // MARK: - Public Properties
    weak var output: NewCardsBaseViewOutput?

    // MARK: Depenencies
    private let flags: RuuviLocalFlags

    // MARK: Properties
    /// Mapping of tab identifier to its view controller
    private let tabs: [CardsMenuType: UIViewController]

    /// Currently visible tab
    private var activeTab: CardsMenuType

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

    private lazy var menuBarView: CardsMenuBarView = {
        let view = CardsMenuBarView(
            menuMode: flags.showRedesignedCardsUIWithNewMenu ? .modern : .legacy
        )
        view.backgroundColor = .clear
        return view
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
        label.text = "Full sensor card"
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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        setUpHeaderViewIfNeeded()
//        output?.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        headerView.alpha = 0
//        output?.viewWillDisappear()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        if parent == nil {
            headerView.alpha = 0
            TimestampUpdateService.shared.removeSubscriber(self)
        } else {
            headerView.alpha = 1
        }
    }

    deinit {
        TimestampUpdateService.shared.removeSubscriber(self)
    }

    // MARK: - Setup
    func setUpUI() {
        setUpBaseView()
        setUpSecondaryToolbarView()
        setUpTabContainer()
        setUpFooterView()
        embedChildViewControllers()
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.primary.color

        view.addSubview(cardBackgroundView)
        cardBackgroundView.fillSuperview()

        view.addSubview(chartViewBackground)
        chartViewBackground.fillSuperview()
        chartViewBackground.alpha = 0
    }

    func setUpHeaderViewIfNeeded() {
        if headerView.superview != nil {
            if headerView.alpha == 0 {
                headerView.alpha = 1
            }
        } else {
            headerView.addSubview(backButtonView)
            backButtonView.anchor(
                top: headerView.topAnchor,
                leading: headerView.leadingAnchor,
                bottom: headerView.bottomAnchor,
                trailing: nil,
                size: .init(width: 40, height: 0)
            )

            headerView.addSubview(ruuviLogoView)
            ruuviLogoView.anchor(
                top: nil,
                leading: backButton.trailingAnchor,
                bottom: nil,
                trailing: nil,
                padding: .init(top: 0, left: 8, bottom: 0, right: 0),
                size: .init(width: 90, height: 22)
            )
            ruuviLogoView.centerYAnchor
                .constraint(
                    equalTo: headerView.centerYAnchor,
                    constant: -2
                ).isActive = true

            headerView.addSubview(activityIndicator)
            activityIndicator.centerInSuperview()

            headerView.addSubview(menuBarView)
            menuBarView
                .anchor(
                    top: headerView.topAnchor,
                    leading: nil,
                    bottom: headerView.bottomAnchor,
                    trailing: headerView.trailingAnchor,
                    padding: .init(top: 0, left: 0, bottom: 0, right: 10),
                    size: .init(width: 120, height: 0)
                )
            menuBarView.onTabChanged = { [weak self] tab in
                print("Changed to: \(tab)")
                self?.handleTabChange(tab)
            }

            UIView.performWithoutAnimation {
                navigationController?.navigationBar.addSubview(headerView)
                headerView.fillSuperviewToSafeArea()
                headerView.alpha = 1
                navigationController?.navigationBar.layoutIfNeeded()
            }
        }
    }

    func setUpSecondaryToolbarView() {
        view.addSubview(secondaryToolbarView)
        secondaryToolbarView.anchor(
            top: view.safeTopAnchor,
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

    func setUpTabContainer() {
        view.addSubview(tabContainerView)

        tabContainerView.anchor(
            top: secondaryToolbarView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(top: 8, left: 0, bottom: 8, right: 0)
        )
    }

    func setUpFooterView() {
        view.addSubview(footerView)
        footerView.anchor(
            top: tabContainerView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: view.safeBottomAnchor,
            trailing: view.safeRightAnchor,
            size: .init(width: 0, height: 30) // Remove this later
        )
    }

    private func embedChildViewControllers() {
        for (tab, vc) in tabs {
            addChild(vc)
            tabContainerView.addSubview(vc.view)
            vc.view.fillSuperviewToSafeArea()
            vc.didMove(toParent: self)
            vc.view.isHidden = tab != activeTab
        }
    }
}

// MARK: Actions
private extension NewCardsBaseViewController {
    @objc func backButtonDidTap() {
        // TODO: Clean properly
//        output?.backButtonDidTap()
        navigationController?.popViewController(animated: true)
    }

    @objc func cardLeftArrowButtonDidTap() {
//        guard currentSnapshotIndex > 0 else { return }
//        let newIndex = currentSnapshotIndex - 1
//        output?.viewDidNavigateToSnapshot(at: newIndex)
    }

    @objc func cardRightArrowButtonDidTap() {
//        guard currentSnapshotIndex < currentSnapshots.count - 1 else { return }
//        let newIndex = currentSnapshotIndex + 1
//        output?.viewDidNavigateToSnapshot(at: newIndex)
    }
}

// MARK: - Private Helpers
private extension NewCardsBaseViewController {

    func showTabViewController(for tab: CardsMenuType) {
        // Hide all tabs
        tabs.values.forEach { $0.view.isHidden = true }
        // Show selected
        if let selectedVC = tabs[tab] {
            selectedVC.view.isHidden = false
        }
    }

    func handleTabChange(_ tab: CardsMenuType) {
        if flags.showRedesignedCardsUIWithoutNewMenu {
            switch tab {
            case .measurement, .graph:
                UIView.animate(withDuration: 0.3, animations: { [weak self] in
                    self?.chartViewBackground.alpha = tab == .graph ? 1 : 0
                })
                showTabViewController(for: tab)
                activeTab = tab
            case .alerts, .settings:
                output?.viewDidChangeTab(tab)
            }
        } else if flags.showRedesignedCardsUIWithNewMenu {
            showTabViewController(for: tab)
            activeTab = tab
            menuBarView.setSelectedTab(tab, animated: true)
        }
    }
}

// MARK: - NewCardsBaseViewInput
extension NewCardsBaseViewController: NewCardsBaseViewInput {
    func setActiveTab(_ tab: CardsMenuType) {
        handleTabChange(tab)
    }

    func setSnapshots(_ snapshots: [RuuviTagCardSnapshot]) {
    }

    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot) {
    }

    func setActiveSnapshotIndex(_ index: Int) {
    }
}
