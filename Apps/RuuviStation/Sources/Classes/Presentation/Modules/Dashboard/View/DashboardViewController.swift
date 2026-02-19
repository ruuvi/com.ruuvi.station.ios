// swiftlint:disable file_length

import Humidity
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit

// MARK: - Main View Controller
final class DashboardViewController: UIViewController {

    // MARK: - Configuration Properties
    var output: DashboardViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var measurementService: RuuviServiceMeasurement!
    var flags: RuuviLocalFlags!

    // MARK: - Data Properties
    var isAuthorized: Bool = false {
        didSet {
            noSensorView.updateView(userSignedIn: isAuthorized)
        }
    }

    var dashboardType: DashboardType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
            updateSnapshot(redrawLayout: true, animated: false)
        }
    }

    var dashboardTapActionType: DashboardTapActionType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
        }
    }

    var dashboardSortingType: DashboardSortingType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
        }
    }

    var isRefreshing: Bool = false {
        didSet {
            updateActivityIndicator()
        }
    }

    var shouldShowSignInBanner: Bool = false {
        didSet {
            showNoSignInBannerIfNeeded()
        }
    }

    // MARK: - Private Properties
    private(set) var snapshots: [RuuviTagCardSnapshot] = []
    private var dataSource:
        UICollectionViewDiffableDataSource<MasonrySection, RuuviTagCardSnapshot>!
    private let heightCache = DashboardCardHeightCache()

    // MARK: - UI Properties
    private lazy var noSensorView: NoSensorView = {
        let view = NoSensorView()
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.delegate = self
        return view
    }()

    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.ruuviLogo.image.withRenderingMode(.alwaysTemplate),
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.logoTintColor.color
        return iv
    }()

    private lazy var menuButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: RuuviAsset.baselineMenuWhite48pt.image,
            tintColor: RuuviColor.menuTintColor.color,
            iconSize: .init(width: 36, height: 36),
            leadingPadding: 6,
            trailingPadding: 6
        )
        button.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleMenuButtonTap))
        )
        return button
    }()

    private lazy var viewButton: RuuviContextMenuButton = .init(
        menu: viewToggleMenuOptions(),
        titleColor: RuuviColor.dashboardIndicator.color,
        title: RuuviLocalization.view,
        icon: RuuviAsset.arrowDropDown.image,
        iconTintColor: RuuviColor.logoTintColor.color,
        iconSize: .init(width: 14, height: 14),
        preccedingIcon: false
    )

    private lazy var dashboardSignInBannerView: DashboardSignInBannerView = {
        let view = DashboardSignInBannerView()
        view.delegate = self
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = MasonryReorderableLayout()
        layout.delegate = self

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
        cv.alwaysBounceVertical = true
        cv.refreshControl = refresher
        return cv
    }()

    private lazy var refresher: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = RuuviColor.tintColor.color
        rc.layer.zPosition = -1
        rc.alpha = 0
        rc.addTarget(self, action: #selector(handleRefreshValueChanged), for: .valueChanged)
        return rc
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = RuuviColor.dashboardIndicator.color
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - Search UI
    private lazy var searchButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "magnifyingglass"),
            tintColor: RuuviColor.dashboardIndicator.color,
            iconSize: .init(width: 20, height: 20),
            leadingPadding: 4,
            trailingPadding: 4
        )
        button.addGestureRecognizer(
            UITapGestureRecognizer(target: self, action: #selector(handleSearchButtonTap))
        )
        return button
    }()

    private lazy var searchTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = RuuviLocalization.sensorSearchPlaceholder
        tf.backgroundColor = RuuviColor.dashboardCardBG.color
        tf.textColor = RuuviColor.dashboardIndicator.color
        tf.clearButtonMode = .whileEditing
        tf.returnKeyType = .search
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.layer.cornerRadius = 8
        tf.layer.masksToBounds = true
        let leftPadding = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 0))
        tf.leftView = leftPadding
        tf.leftViewMode = .always
        tf.rightView = searchLoadingIndicator
        tf.rightViewMode = .always
        tf.delegate = self
        tf.addTarget(self, action: #selector(searchTextChanged(_:)), for: .editingChanged)
        return tf
    }()

    private lazy var searchCancelButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(RuuviLocalization.cancel, for: .normal)
        btn.setTitleColor(RuuviColor.tintColor.color, for: .normal)
        btn.addTarget(self, action: #selector(handleSearchCancelTap), for: .touchUpInside)
        return btn
    }()

    private lazy var searchLoadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = RuuviColor.dashboardIndicator.color
        indicator.hidesWhenStopped = true
        indicator.alpha = 0
        return indicator
    }()

    private lazy var searchContainerView: UIView = {
        let container = UIView()
        container.backgroundColor = .clear

        container.addSubview(searchTextField)
        container.addSubview(searchCancelButton)

        searchTextField.translatesAutoresizingMaskIntoConstraints = false
        searchCancelButton.translatesAutoresizingMaskIntoConstraints = false
        searchCancelButton.setContentHuggingPriority(.required, for: .horizontal)
        searchCancelButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            searchTextField.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            searchTextField.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            searchTextField.heightAnchor.constraint(equalToConstant: 32),
            searchTextField.trailingAnchor.constraint(
                equalTo: searchCancelButton.leadingAnchor,
                constant: -8
            ),

            searchCancelButton.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            searchCancelButton.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        return container
    }()

    // MARK: - Custom Header View (iOS 26+)
    private lazy var customHeaderView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }()

    private lazy var headerLeftContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = true
        return view
    }()

    // MARK: - Constraints
    private var customHeaderHeightConstraint: NSLayoutConstraint?
    private var showSignInBannerConstraint: NSLayoutConstraint!
    private var hideSignInBannerConstraint: NSLayoutConstraint!

    // MARK: - Text Field Properties
    private var tagNameTextField = UITextField()
    private let tagNameCharacterLimit: Int = 32

    // MARK: - Refresh Control Properties
    private var isListRefreshable: Bool = true
    private var isPulling: Bool = false
    private var isContextMenuPresented: Bool = false

    // MARK: - Drag and reorder Properties
    private var currentSnapshotIdentifiers: [RuuviTagCardSnapshot] = []
    private var isDragSessionInProgress: Bool = false
    private var isReadyForAnimations: Bool = false

    // MARK: - Search Properties
    private var searchText: String = ""
    private var isSearchActive: Bool = false
    private var searchDebounceWorkItem: DispatchWorkItem?
    private var savedLeftBarButtonItem: UIBarButtonItem?
    private var savedRightBarButtonItem: UIBarButtonItem?
    private var savedTitleView: UIView?
    private var hasAppliedInitialNonEmptySnapshot = false

    // MARK: - Observers
    private var appDidBecomeActiveToken: NSObjectProtocol?

    // MARK: - Lifecycle
    deinit {
        cleanup()
    }
}

// MARK: - View Lifecycle
extension DashboardViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewController()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let shouldAnimateTransition = shouldAnimate(animated)
        if #available(iOS 26.0, *) {
            navigationController?.setNavigationBarHidden(true, animated: shouldAnimateTransition)
        } else {
            navigationController?.makeTransparent()
        }
        output.viewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        isReadyForAnimations = true
        AppUtility.lockOrientation(.all)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let shouldAnimateTransition = shouldAnimate(animated)
        if #available(iOS 26.0, *) {
            navigationController?.setNavigationBarHidden(false, animated: shouldAnimateTransition)
        } else {
            navigationController?.resetStyleToDefault()
        }
        output.viewWillDisappear()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        updateSnapshot(redrawLayout: false, animated: shouldAnimate(true))
    }
}

// MARK: - Setup Methods
private extension DashboardViewController {
    func shouldAnimate(_ animated: Bool) -> Bool {
        return isReadyForAnimations && animated
    }

    func setupViewController() {
        setupUI()
        setupDataSource()
        configureRestartAnimationsOnAppDidBecomeActive()
        localize()
        output.viewDidLoad()
    }

    func setupUI() {
        view.backgroundColor = RuuviColor.dashboardBG.color
        setupHeaderView()
        setupNoSensorView()
        setupContentView()
    }

    func setupNoSensorView() {
        view.addSubview(noSensorView)
        if #available(iOS 26.0, *) {
            noSensorView.anchor(
                top: customHeaderView.bottomAnchor,
                leading: view.safeLeftAnchor,
                bottom: view.safeBottomAnchor,
                trailing: view.safeRightAnchor,
                padding: .init(top: 12, left: 12, bottom: 12, right: 12)
            )
        } else {
            noSensorView.anchor(
                top: view.safeTopAnchor,
                leading: view.safeLeftAnchor,
                bottom: view.safeBottomAnchor,
                trailing: view.safeRightAnchor,
                padding: .init(top: 12, left: 12, bottom: 12, right: 12)
            )
        }
        noSensorView.isHidden = true
    }

    func setupHeaderView() {
        if #available(iOS 26.0, *) {
            setupCustomHeaderView()
        } else {
            setupNavigationBarItems()
        }
    }

    func setupNavigationBarItems() {
        let leftBarButtonView = createLeftBarButtonView()
        let rightBarButtonView = createRightBarButtonView()
        let titleView = createTitleView()

        navigationItem.titleView = titleView
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    @available(iOS 26.0, *)
    func setupCustomHeaderView() {
        view.addSubview(customHeaderView)
        customHeaderView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            customHeaderView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            customHeaderView.leadingAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            customHeaderView.trailingAnchor
                .constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            customHeaderView.heightAnchor.constraint(equalToConstant: 44),
        ])

        // Left side: Menu button + Ruuvi logo
        customHeaderView.addSubview(headerLeftContainer)

        menuButton.translatesAutoresizingMaskIntoConstraints = false
        menuButton.isUserInteractionEnabled = true
        headerLeftContainer.addSubview(menuButton)

        ruuviLogoView.translatesAutoresizingMaskIntoConstraints = false
        headerLeftContainer.addSubview(ruuviLogoView)

        NSLayoutConstraint.activate([
            headerLeftContainer.leadingAnchor.constraint(
                equalTo: customHeaderView.leadingAnchor,
                constant: 4
            ),
            headerLeftContainer.centerYAnchor.constraint(equalTo: customHeaderView.centerYAnchor),
            headerLeftContainer.heightAnchor.constraint(equalToConstant: 44),

            menuButton.leadingAnchor
                .constraint(equalTo: headerLeftContainer.leadingAnchor, constant: 4),
            menuButton.centerYAnchor.constraint(equalTo: headerLeftContainer.centerYAnchor),

            ruuviLogoView.leadingAnchor.constraint(equalTo: menuButton.trailingAnchor, constant: 4),
            ruuviLogoView.centerYAnchor.constraint(equalTo: headerLeftContainer.centerYAnchor),
            ruuviLogoView.widthAnchor.constraint(equalToConstant: 90),
            ruuviLogoView.heightAnchor.constraint(equalToConstant: 22),
            ruuviLogoView.trailingAnchor.constraint(equalTo: headerLeftContainer.trailingAnchor),
        ])

        // Center: Activity indicator
        customHeaderView.addSubview(activityIndicator)
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: customHeaderView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: customHeaderView.centerYAnchor),
        ])

        // Right side: View button (and optional search button)
        customHeaderView.addSubview(viewButton)
        viewButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            viewButton.trailingAnchor.constraint(equalTo: customHeaderView.trailingAnchor, constant: -16),
            viewButton.centerYAnchor.constraint(equalTo: customHeaderView.centerYAnchor),
            viewButton.heightAnchor.constraint(equalToConstant: 32),
        ])

        if flags.showDashboardSensorSearch {
            customHeaderView.addSubview(searchButton)
            searchButton.translatesAutoresizingMaskIntoConstraints = false

            NSLayoutConstraint.activate([
                searchButton.trailingAnchor.constraint(equalTo: viewButton.leadingAnchor, constant: -4),
                searchButton.centerYAnchor.constraint(equalTo: customHeaderView.centerYAnchor),
                searchButton.widthAnchor.constraint(equalToConstant: 36),
                searchButton.heightAnchor.constraint(equalToConstant: 32),
            ])

            // Search overlay - covers the full header when search is active
            customHeaderView.addSubview(searchContainerView)
            searchContainerView.translatesAutoresizingMaskIntoConstraints = false
            searchContainerView.isHidden = true
            searchContainerView.alpha = 0

            NSLayoutConstraint.activate([
                searchContainerView.topAnchor.constraint(equalTo: customHeaderView.topAnchor),
                searchContainerView.leadingAnchor.constraint(equalTo: customHeaderView.leadingAnchor),
                searchContainerView.trailingAnchor.constraint(equalTo: customHeaderView.trailingAnchor),
                searchContainerView.bottomAnchor.constraint(equalTo: customHeaderView.bottomAnchor),
            ])
        }
    }

    func createLeftBarButtonView() -> UIView {
        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(menuButton)
        menuButton.anchor(
            top: leftBarButtonView.topAnchor,
            leading: leftBarButtonView.leadingAnchor,
            bottom: leftBarButtonView.bottomAnchor,
            trailing: nil,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0)
        )

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: menuButton.trailingAnchor,
            bottom: nil,
            trailing: leftBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 0),
            size: .init(width: 90, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        return leftBarButtonView
    }

    func createRightBarButtonView() -> UIView {
        let rightBarButtonView = UIView(color: .clear)

        if flags.showDashboardSensorSearch {
            rightBarButtonView.addSubview(searchButton)
            searchButton.anchor(
                top: rightBarButtonView.topAnchor,
                leading: rightBarButtonView.leadingAnchor,
                bottom: rightBarButtonView.bottomAnchor,
                trailing: nil,
                size: .init(width: 36, height: 32)
            )
            rightBarButtonView.addSubview(viewButton)
            viewButton.anchor(
                top: rightBarButtonView.topAnchor,
                leading: searchButton.trailingAnchor,
                bottom: rightBarButtonView.bottomAnchor,
                trailing: rightBarButtonView.trailingAnchor,
                padding: .init(top: 0, left: 4, bottom: 0, right: 4),
                size: .init(width: 0, height: 32)
            )
        } else {
            rightBarButtonView.addSubview(viewButton)
            viewButton.anchor(
                top: rightBarButtonView.topAnchor,
                leading: rightBarButtonView.leadingAnchor,
                bottom: rightBarButtonView.bottomAnchor,
                trailing: rightBarButtonView.trailingAnchor,
                padding: .init(top: 0, left: 0, bottom: 0, right: 4),
                size: .init(width: 0, height: 32)
            )
        }

        return rightBarButtonView
    }

    func createTitleView() -> UIView {
        let titleView = UIView(color: .clear)
        titleView.addSubview(activityIndicator)
        activityIndicator.fillSuperview()
        return titleView
    }

    func setupContentView() {
        setupSignInBanner()
        setupCollectionView()
        setupPanGesture()
    }

    func setupSignInBanner() {
        view.addSubview(dashboardSignInBannerView)
        if #available(iOS 26.0, *) {
            dashboardSignInBannerView.anchor(
                top: customHeaderView.bottomAnchor,
                leading: view.safeLeftAnchor,
                bottom: nil,
                trailing: view.safeRightAnchor
            )
        } else {
            dashboardSignInBannerView.anchor(
                top: view.safeTopAnchor,
                leading: view.safeLeftAnchor,
                bottom: nil,
                trailing: view.safeRightAnchor
            )
        }
        dashboardSignInBannerView.alpha = 0
    }

    func setupCollectionView() {
        view.addSubview(collectionView)
        collectionView.anchor(
            top: nil,
            leading: view.safeLeftAnchor,
            bottom: view.bottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(top: 0, left: 6, bottom: 0, right: 6)
        )

        setupCollectionViewConstraints()
        registerCollectionViewCell()
    }

    func setupCollectionViewConstraints() {
        showSignInBannerConstraint = collectionView.topAnchor.constraint(
            equalTo: dashboardSignInBannerView.bottomAnchor,
            constant: 8
        )

        if #available(iOS 26.0, *) {
            hideSignInBannerConstraint = collectionView.topAnchor.constraint(
                equalTo: customHeaderView.bottomAnchor,
                constant: 4
            )
        } else {
            hideSignInBannerConstraint = collectionView.topAnchor.constraint(
                equalTo: view.safeTopAnchor,
                constant: 4
            )
        }
        hideSignInBannerConstraint.isActive = true
    }

    func registerCollectionViewCell() {
        collectionView.register(
            DashboardCell.self,
            forCellWithReuseIdentifier: Constants.CellIdentifiers.dashboardCell
        )
    }

    func setupPanGesture() {
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        collectionView.addGestureRecognizer(panGesture)
    }
}

// MARK: - Data Source Setup
private extension DashboardViewController {
    func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<MasonrySection, RuuviTagCardSnapshot>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, snapshot in
            self?.configureCell(collectionView: collectionView, indexPath: indexPath, snapshot: snapshot)
        }

        applyInitialSnapshot()
        configureMasonryLayout()
    }

    func configureCell(
        collectionView: UICollectionView,
        indexPath: IndexPath,
        snapshot: RuuviTagCardSnapshot
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Constants.CellIdentifiers.dashboardCell,
            for: indexPath
        ) as? DashboardCell else {
            return UICollectionViewCell()
        }

        cell
            .configure(
                with: snapshot,
                dashboardType: dashboardType
            )
        cell.delegate = self
        cell.setMenu(cardContextMenuOption(for: indexPath))
        return cell
    }

    func applyInitialSnapshot() {
        var initialSnapshot = NSDiffableDataSourceSnapshot<MasonrySection, RuuviTagCardSnapshot>()
        initialSnapshot.appendSections([.main])
        dataSource.apply(initialSnapshot, animatingDifferences: false)
    }

    func configureMasonryLayout() {
        if let layout = collectionView.collectionViewLayout as? MasonryReorderableLayout {
            layout.setDataSource(dataSource)
        }
    }
}

// MARK: - Observer Management
private extension DashboardViewController {
    func cleanup() {
        appDidBecomeActiveToken?.invalidate()
        searchDebounceWorkItem?.cancel()
    }

    func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken?.invalidate()
        appDidBecomeActiveToken = nil
        appDidBecomeActiveToken = NotificationCenter
                .default
                .addObserver(
                    forName: UIApplication.willEnterForegroundNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.restartAlertAnimations()
                }
    }

    func restartAlertAnimations() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        for indexPath in visibleIndexPaths {
            if let cell = collectionView.cellForItem(at: indexPath) as? DashboardCell {
                cell.restartAlertAnimationIfNeeded()
            }
        }
    }
}

// MARK: - Data Management
private extension DashboardViewController {
    func updateData(
        with newSnapshots: [RuuviTagCardSnapshot],
        animated: Bool = true
    ) {
        guard !isDragSessionInProgress, !isContextMenuPresented else { return }
        let shouldAnimateDiff = shouldAnimate(animated) && hasAppliedInitialNonEmptySnapshot

        var snapshot = NSDiffableDataSourceSnapshot<MasonrySection, RuuviTagCardSnapshot>()
        snapshot.appendSections([.main])
        snapshot.appendItems(newSnapshots)
        dataSource.apply(snapshot, animatingDifferences: shouldAnimateDiff)

        if !hasAppliedInitialNonEmptySnapshot, !newSnapshots.isEmpty {
            hasAppliedInitialNonEmptySnapshot = true
        }
    }

    func updateActivityIndicator() {
        if isRefreshing {
            activityIndicator.startAnimating()
        } else {
            activityIndicator.stopAnimating()
        }
    }
}

// MARK: - Collection View Management
private extension DashboardViewController {
    func updateSnapshot(redrawLayout: Bool, animated: Bool) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard !self.isDragSessionInProgress,
            !self.isContextMenuPresented else { return }

            if redrawLayout {
                self.heightCache.clearCache()
            }

            guard let dataSource = self.dataSource else { return }

            var newSnapshot = dataSource.snapshot()
            if redrawLayout {
                newSnapshot.reloadItems(newSnapshot.itemIdentifiers)
            } else {
                newSnapshot.reconfigureItems(newSnapshot.itemIdentifiers)
            }
            self.dataSource.apply(
                newSnapshot,
                animatingDifferences: self.shouldAnimate(animated)
            ) { [weak self] in
                if redrawLayout {
                    self?.collectionView.collectionViewLayout.invalidateLayout()
                }
            }
        }
    }
}

// MARK: - Action Handlers
private extension DashboardViewController {
    @objc func handleMenuButtonTap() {
        output.viewDidTriggerMenu()
    }

    @objc func handleRefreshValueChanged() {
        isPulling = true
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .ended && isPulling {
            isPulling = false
            refresher.endRefreshing()
            output.viewDidTriggerPullToRefresh()
        }
    }

    @objc func handleSearchButtonTap() {
        activateSearch()
    }

    @objc func searchTextChanged(_ textField: UITextField) {
        searchText = textField.text ?? ""
        performSearchWithLoadingAnimation()
    }

    @objc func handleSearchCancelTap() {
        deactivateSearch()
    }
}

// MARK: - Search Management
private extension DashboardViewController {
    var displayedSnapshots: [RuuviTagCardSnapshot] {
        guard !searchText.isEmpty else { return snapshots }
        return snapshots.filter {
            $0.displayData.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    func activateSearch() {
        isSearchActive = true
        if #available(iOS 26.0, *) {
            activateSearchiOS26()
        } else {
            activateSearchLegacy()
        }
        searchTextField.becomeFirstResponder()
    }

    func deactivateSearch() {
        isSearchActive = false
        searchDebounceWorkItem?.cancel()
        searchText = ""
        searchTextField.text = ""
        searchTextField.resignFirstResponder()
        if #available(iOS 26.0, *) {
            deactivateSearchiOS26()
        } else {
            deactivateSearchLegacy()
        }
        stopSearchLoadingAnimation()
        updateData(with: snapshots, animated: false)
    }

    func performSearchWithLoadingAnimation() {
        searchDebounceWorkItem?.cancel()
        startSearchLoadingAnimation()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            UIView.transition(
                with: self.collectionView,
                duration: 0.2,
                options: [.transitionCrossDissolve, .allowUserInteraction]
            ) {
                self.updateData(with: self.displayedSnapshots, animated: false)
            } completion: { _ in
                self.stopSearchLoadingAnimation()
            }
        }

        searchDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    func startSearchLoadingAnimation() {
        searchLoadingIndicator.startAnimating()
        UIView.animate(withDuration: 0.15) {
            self.searchLoadingIndicator.alpha = 1
        }
    }

    func stopSearchLoadingAnimation() {
        UIView.animate(withDuration: 0.15) {
            self.searchLoadingIndicator.alpha = 0
        } completion: { _ in
            self.searchLoadingIndicator.stopAnimating()
        }
    }

    @available(iOS 26.0, *)
    func activateSearchiOS26() {
        searchContainerView.isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.searchContainerView.alpha = 1
            self.headerLeftContainer.alpha = 0
            self.activityIndicator.alpha = 0
            self.searchButton.alpha = 0
            self.viewButton.alpha = 0
        }
    }

    @available(iOS 26.0, *)
    func deactivateSearchiOS26() {
        UIView.animate(withDuration: 0.2) {
            self.searchContainerView.alpha = 0
            self.headerLeftContainer.alpha = 1
            self.activityIndicator.alpha = 1
            self.searchButton.alpha = 1
            self.viewButton.alpha = 1
        } completion: { _ in
            self.searchContainerView.isHidden = true
        }
    }

    func activateSearchLegacy() {
        savedLeftBarButtonItem = navigationItem.leftBarButtonItem
        savedRightBarButtonItem = navigationItem.rightBarButtonItem
        savedTitleView = navigationItem.titleView

        navigationItem.setLeftBarButton(nil, animated: false)
        navigationItem.setRightBarButton(nil, animated: false)

        let width = view.bounds.width - 32
        searchContainerView.frame = CGRect(x: 0, y: 0, width: width, height: 40)
        searchContainerView.alpha = 0
        navigationItem.titleView = searchContainerView
        UIView.animate(withDuration: 0.2) {
            self.searchContainerView.alpha = 1
        }
    }

    func deactivateSearchLegacy() {
        UIView.animate(withDuration: 0.2) {
            self.searchContainerView.alpha = 0
        } completion: { _ in
            self.navigationItem.titleView = self.savedTitleView
            if let left = self.savedLeftBarButtonItem {
                self.navigationItem.setLeftBarButton(left, animated: false)
            }
            if let right = self.savedRightBarButtonItem {
                self.navigationItem.setRightBarButton(right, animated: false)
            }
            self.savedLeftBarButtonItem = nil
            self.savedRightBarButtonItem = nil
            self.savedTitleView = nil
            self.searchContainerView.alpha = 1
        }
    }
}

// MARK: - Menu Configuration
private extension DashboardViewController {
    func viewToggleMenuOptions() -> UIMenu {
        let cardTypeMenu = createCardTypeMenu()
        let cardActionMenu = createCardActionMenu()

        var menuItems: [UIMenuElement] = [cardTypeMenu, cardActionMenu]

        if dashboardSortingType == .manual {
            let resetSensorSortingOrderMenu = createResetSortingMenu()
            menuItems.append(resetSensorSortingOrderMenu)
        }

        return UIMenu(title: "", children: menuItems)
    }

    func createCardTypeMenu() -> UIMenu {
        let imageViewTypeAction = UIAction(title: RuuviLocalization.imageCards) { [weak self] _ in
            self?.handleDashboardTypeChange(.image)
        }

        let simpleViewTypeAction = UIAction(title: RuuviLocalization.simpleCards) { [weak self] _ in
            self?.handleDashboardTypeChange(.simple)
        }

        simpleViewTypeAction.state = dashboardType == .simple ? .on : .off
        imageViewTypeAction.state = dashboardType == .image ? .on : .off

        return UIMenu(
            title: RuuviLocalization.cardType,
            options: .displayInline,
            children: [imageViewTypeAction, simpleViewTypeAction]
        )
    }

    func createCardActionMenu() -> UIMenu {
        let openSensorViewAction = UIAction(title: RuuviLocalization.openSensorView) { [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .card)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let openHistoryViewAction = UIAction(title: RuuviLocalization.openHistoryView) { [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .chart)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        openSensorViewAction.state = dashboardTapActionType == .card ? .on : .off
        openHistoryViewAction.state = dashboardTapActionType == .chart ? .on : .off

        return UIMenu(
            title: RuuviLocalization.cardAction,
            options: .displayInline,
            children: [openSensorViewAction, openHistoryViewAction]
        )
    }

    func createResetSortingMenu() -> UIMenu {
        let resetSensorSortingOrderAction = UIAction(title: RuuviLocalization.resetOrder) { [weak self] _ in
            self?.output.viewDidResetManualSorting()
        }
        resetSensorSortingOrderAction.state = .off

        return UIMenu(
            title: RuuviLocalization.ordering,
            options: .displayInline,
            children: [resetSensorSortingOrderAction]
        )
    }

    func handleDashboardTypeChange(_ type: DashboardType) {
        output.viewDidChangeDashboardType(dashboardType: type)
        viewButton.updateMenu(with: viewToggleMenuOptions())
    }
}

// MARK: - Context Menu Configuration
private extension DashboardViewController {
    func cardContextMenuOption(for indexPath: IndexPath) -> UIMenu {
        let basicActions = createBasicContextMenuActions(for: indexPath)
        var contextMenuActions = basicActions

        // Add reorder actions if multiple sensors exist
        if dataSource.snapshot().numberOfItems > 1 {
            let reorderActions = createReorderActions(for: indexPath)
            contextMenuActions.append(contentsOf: reorderActions)
        }

        // Add share action if applicable
        if let snapshot = dataSource.itemIdentifier(for: indexPath),
           snapshot.metadata.canShareTag {
            let shareAction = createShareAction(for: indexPath)
            contextMenuActions.append(shareAction)
        }

        // Add remove action
        let removeAction = createRemoveAction(for: indexPath)
        contextMenuActions.append(removeAction)

        return UIMenu(title: "", children: contextMenuActions)
    }

    func createBasicContextMenuActions(for indexPath: IndexPath) -> [UIAction] {
        let fullImageViewAction = UIAction(title: RuuviLocalization.fullImageView) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerOpenCardImageView(for: snapshot)
            }
        }

        let historyViewAction = UIAction(title: RuuviLocalization.historyView) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerChart(for: snapshot)
            }
        }

        let settingsAction = UIAction(title: RuuviLocalization.settingsAndAlerts) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerSettings(for: snapshot)
            }
        }

        let changeBackgroundAction = UIAction(title: RuuviLocalization.changeBackground) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerChangeBackground(for: snapshot)
            }
        }

        let renameAction = UIAction(title: RuuviLocalization.rename) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerRename(for: snapshot)
            }
        }

        return [
            fullImageViewAction,
            historyViewAction,
            settingsAction,
            changeBackgroundAction,
            renameAction,
        ]
    }

    func createReorderActions(for indexPath: IndexPath) -> [UIAction] {
        let totalItems = dataSource.snapshot().numberOfItems
        var actions: [UIAction] = []

        // Add move up action (not for first item)
        if indexPath.item > 0 {
            let moveUpAction = UIAction(title: RuuviLocalization.moveUp) { [weak self] _ in
                self?.isContextMenuPresented = false
                self?.handleMoveUp(at: indexPath)
            }
            actions.append(moveUpAction)
        }

        // Add move down action (not for last item)
        if indexPath.item < totalItems - 1 {
            let moveDownAction = UIAction(title: RuuviLocalization.moveDown) { [weak self] _ in
                self?.isContextMenuPresented = false
                self?.handleMoveDown(at: indexPath)
            }
            actions.append(moveDownAction)
        }

        return actions
    }

    func createShareAction(for indexPath: IndexPath) -> UIAction {
        return UIAction(title: RuuviLocalization.TagSettings.shareButton) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerShare(for: snapshot)
            }
        }
    }

    func createRemoveAction(for indexPath: IndexPath) -> UIAction {
        return UIAction(title: RuuviLocalization.remove) { [weak self] _ in
            self?.handleContextMenuAction(at: indexPath) { snapshot in
                self?.output.viewDidTriggerRemove(for: snapshot)
            }
        }
    }

    func handleContextMenuAction(at indexPath: IndexPath, action: (RuuviTagCardSnapshot) -> Void) {
        guard let snapshot = dataSource.itemIdentifier(for: indexPath) else { return }
        isContextMenuPresented = false
        action(snapshot)
    }

    func handleMoveUp(at indexPath: IndexPath) {
        guard let snapshot = dataSource.itemIdentifier(for: indexPath),
              let mac = snapshot.identifierData.mac?.mac else { return }

        let ids = snapshots.compactMap(\.identifierData.mac?.mac)
        let reordered = ids.movingUp(mac)
        output.viewDidReorderSensors(with: .manual, orderedIds: reordered)
        // Force refresh context menus after reordering
        DispatchQueue.main.async { [weak self] in
            self?.refreshContextMenus()
        }
    }

    func handleMoveDown(at indexPath: IndexPath) {
        guard let snapshot = dataSource.itemIdentifier(for: indexPath),
              let mac = snapshot.identifierData.mac?.mac else { return }

        let ids = snapshots.compactMap(\.identifierData.mac?.mac)
        let reordered = ids.movingDown(mac)
        output.viewDidReorderSensors(with: .manual, orderedIds: reordered)
        // Force refresh context menus after reordering
        DispatchQueue.main.async { [weak self] in
            self?.refreshContextMenus()
        }
    }
}

// MARK: - Banner Management
private extension DashboardViewController {
    func showNoSignInBannerIfNeeded() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let updates = {
                self.dashboardSignInBannerView.alpha = self.shouldShowSignInBanner ? 1 : 0

                if self.shouldShowSignInBanner {
                    NSLayoutConstraint.deactivate([self.hideSignInBannerConstraint])
                    NSLayoutConstraint.activate([self.showSignInBannerConstraint])
                } else {
                    NSLayoutConstraint.deactivate([self.showSignInBannerConstraint])
                    NSLayoutConstraint.activate([self.hideSignInBannerConstraint])
                }

                self.view.layoutIfNeeded()
            }

            if self.shouldAnimate(true) {
                UIView.animate(withDuration: 0.3, animations: updates)
            } else {
                UIView.performWithoutAnimation(updates)
            }
        }
    }
}

// MARK: - Constants
private extension DashboardViewController {
    enum Constants {
        enum CellIdentifiers {
            static let dashboardCell = "RuuviTagDashboardCell"
        }
    }
}

// MARK: - Masonry Layout Delegate
extension DashboardViewController: MasonryReorderableLayoutDelegate {

    func collectionView(
        _ collectionView: UICollectionView,
        heightForItemAt indexPath: IndexPath
    ) -> CGFloat {
        let snapshot = dataSource.snapshot()
        let items = snapshot.itemIdentifiers(
            inSection: .main
        )
        guard indexPath.item < items.count,
              dashboardType != .none else {
            return 200
        }

        let cardSnapshot = items[indexPath.item]
        let numberOfColumns = self.numberOfColumns(
            in: collectionView
        )
        let columnSpacing = self.columnSpacing(
            in: collectionView
        )
        let sectionInsets = self.sectionInsets(
            in: collectionView
        )

        let totalSpacing = columnSpacing * CGFloat(
            numberOfColumns - 1
        )
        let availableWidth = collectionView.bounds.width - sectionInsets.left - sectionInsets.right - totalSpacing
        let itemWidth = availableWidth / CGFloat(
            numberOfColumns
        )

        return heightCache
            .height(
            for: cardSnapshot,
            width: itemWidth,
            displayType: dashboardType,
            numberOfColumns: numberOfColumns
        )
    }

    func numberOfColumns(in collectionView: UICollectionView) -> Int {
        let isLandscape = collectionView.bounds.width > collectionView.bounds.height
        if isLandscape {
            return UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        } else {
            return UIDevice.current.userInterfaceIdiom == .pad ? 2 : 1
        }
    }

    func columnSpacing(in collectionView: UICollectionView) -> CGFloat {
        return 8
    }

    func sectionInsets(in collectionView: UICollectionView) -> UIEdgeInsets {
        return UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
    }

    // MARK: - Drag Callbacks
    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        willBeginDraggingItemAt indexPath: IndexPath
    ) {
        isDragSessionInProgress = true
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        didBeginDraggingItemAt indexPath: IndexPath
    ) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        didEndDraggingItemTo indexPath: IndexPath
    ) {
        // Get the current order directly from the data source
        let currentSnapshot = dataSource.snapshot()
        let currentItems = currentSnapshot.itemIdentifiers(inSection: .main)
        let newMacIds = currentItems.compactMap { $0.identifierData.mac?.value }
        let previousMacIds = snapshots.compactMap { $0.identifierData.mac?.value }

        guard !newMacIds.isEmpty && !previousMacIds.isEmpty else {
            return
        }

        guard Set(newMacIds) == Set(previousMacIds) else {
            return
        }

        guard newMacIds != previousMacIds else {
            return
        }

        output.viewDidReorderSensors(with: .manual, orderedIds: newMacIds)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Force refresh context menus after reordering
        DispatchQueue.main.async { [weak self] in
            self?.refreshContextMenus()
            self?.isDragSessionInProgress = false
        }
    }

    func collectionView(
        _ collectionView: UICollectionView,
        at fromIndexPath: IndexPath,
        didMoveTo toIndexPath: IndexPath,
        currentSnapshots: [RuuviTagCardSnapshot]
    ) {
        currentSnapshotIdentifiers = currentSnapshots
    }

    private func refreshContextMenus() {
        // Force reload visible cells to update context menus
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        for indexPath in visibleIndexPaths {
            if let cell = collectionView.cellForItem(at: indexPath) as? DashboardCell {
                cell.setMenu(cardContextMenuOption(for: indexPath))
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate
extension DashboardViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

// MARK: - UICollectionViewDelegate
extension DashboardViewController: UICollectionViewDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        if let cell = cell as? DashboardCell {
            cell.restartAlertAnimationIfNeeded()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let snapshot = dataSource.itemIdentifier(for: indexPath) else { return }
        output.viewDidTriggerDashboardCard(for: snapshot)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(
            #selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation),
            with: nil,
            afterDelay: 0.3
        )

        if scrollView.isDragging {
            refresher.fadeIn()
            isListRefreshable = false
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        isListRefreshable = true
    }
}

// MARK: - NewDashboardViewInput
extension DashboardViewController: NewDashboardViewInput {
    func localize() {
        // No-op for now
    }

    func updateSnapshots(
        _ snapshots: [RuuviTagCardSnapshot],
        withAnimation: Bool
    ) {
        self.snapshots = snapshots
        showNoSensorsAddedMessage(show: snapshots.isEmpty)
        updateData(with: displayedSnapshots, animated: withAnimation)
    }

    func updateSnapshot(
        from snapshot: RuuviTagCardSnapshot,
        invalidateLayout: Bool
    ) {
        if let snapshotIndex = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
            snapshots[snapshotIndex] = snapshot
        }
        updateSnapshot(redrawLayout: invalidateLayout, animated: true)
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = RuuviLocalization.Cards.BluetoothDisabledAlert.title
        let message = RuuviLocalization.Cards.BluetoothDisabledAlert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.PermissionPresenter.settings,
            style: .default,
            handler: { _ in
                let urlString = userDeclined ?
                    UIApplication.openSettingsURLString : "App-prefs:Bluetooth"
                guard let url = URL(string: urlString),
                      UIApplication.shared.canOpenURL(url) else { return }
                UIApplication.shared.open(url)
            }
        ))

        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.ok,
            style: .cancel,
            handler: nil
        ))

        present(alertVC, animated: true)
    }

    func showNoSensorsAddedMessage(show: Bool) {
        noSensorView.updateView(userSignedIn: isAuthorized)
        noSensorView.isHidden = !show
        collectionView.isHidden = show
    }

    func showKeepConnectionDialogChart(for snapshot: RuuviTagCardSnapshot) {
        showKeepConnectionDialog(
            for: snapshot,
            onDismiss: { [weak self] in
                self?.output.viewDidDismissKeepConnectionDialogChart(for: snapshot)
            },
            onKeep: { [weak self] in
                self?.output.viewDidConfirmToKeepConnectionChart(to: snapshot)
            }
        )
    }

    func showKeepConnectionDialogSettings(
        for snapshot: RuuviTagCardSnapshot,
        newlyAddedSensor: Bool
    ) {
        showKeepConnectionDialog(
            for: snapshot,
            onDismiss: { [weak self] in
                self?.output
                    .viewDidDismissKeepConnectionDialogSettings(
                        for: snapshot,
                        newlyAddedSensor: newlyAddedSensor
                    )
            },
            onKeep: { [weak self] in
                self?.output
                    .viewDidConfirmToKeepConnectionSettings(
                        to: snapshot,
                        newlyAddedSensor: newlyAddedSensor
                    )
            }
        )
    }

    private func showKeepConnectionDialog(
        for snapshot: RuuviTagCardSnapshot,
        onDismiss: @escaping () -> Void,
        onKeep: @escaping () -> Void
    ) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel) { _ in
            onDismiss()
        })

        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default) { _ in
            onKeep()
        })

        present(alert, animated: true)
    }

    func showAlreadyLoggedInAlert(with email: String) {
        let message = RuuviLocalization.Cards.Alert.AlreadyLoggedIn.message(email)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    func showSensorNameRenameDialog(
        for snapshot: RuuviTagCardSnapshot,
        sortingType: DashboardSortingType
    ) {
        let defaultName = GlobalHelpers.ruuviDeviceDefaultName(
            from: snapshot.identifierData.mac?.mac,
            luid: snapshot.identifierData.luid?.value,
            dataFormat: snapshot.displayData.version
        )

        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
            message: sortingType == .alphabetical ?
                RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text : nil,
            preferredStyle: .alert
        )

        alert.addTextField { [weak self] alertTextField in
            guard let self = self else { return }
            alertTextField.delegate = self
            alertTextField.text = (defaultName == snapshot.displayData.name) ? nil : snapshot.displayData.name
            alertTextField.placeholder = defaultName
            self.tagNameTextField = alertTextField
        }

        let okAction = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self = self else { return }
            let name = self.tagNameTextField.text?.isEmpty == false ?
                self.tagNameTextField.text! : defaultName
            self.output.viewDidRenameTag(to: name, snapshot: snapshot)
        }

        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(okAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }

    func showSensorSortingResetConfirmationDialog() {
        let message = RuuviLocalization.resetOrderConfirmation
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel, handler: nil)
        alert.addAction(cancelAction)

        let confirmAction = UIAlertAction(title: RuuviLocalization.confirm, style: .default) { [weak self] _ in
            self?.output.viewDidReorderSensors(with: .alphabetical, orderedIds: [])
        }
        alert.addAction(confirmAction)

        present(alert, animated: true)
    }
}

// MARK: - RuuviTagDashboardCellDelegate
extension DashboardViewController: DashboardCellDelegate {
    func didTapAlertButton(for snapshot: RuuviTagCardSnapshot) {
        output.viewDidTriggerSettings(for: snapshot)
    }

    func didChangeMoreButtonMenuPresentationState(
        for snapshot: RuuviTagCardSnapshot,
        isPresented: Bool
    ) {
        isContextMenuPresented = isPresented
    }
}

// MARK: - NoSensorViewDelegate
extension DashboardViewController: NoSensorViewDelegate {
    func didTapSignInButton(sender: NoSensorView) {
        output.viewDidTriggerSignIn()
    }

    func didTapAddSensorButton(sender: NoSensorView) {
        output.viewDidTriggerAddSensors()
    }

    func didTapBuySensorButton(sender: NoSensorView) {
        output.viewDidTriggerBuySensors()
    }
}

// MARK: - UITextFieldDelegate
extension DashboardViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        guard let text = textField.text, textField == tagNameTextField else { return true }

        let limit = text.utf16.count + string.utf16.count - range.length
        return limit <= tagNameCharacterLimit
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == searchTextField {
            textField.resignFirstResponder()
        }
        return true
    }
}

// MARK: - DashboardSignInBannerViewDelegate
extension DashboardViewController: DashboardSignInBannerViewDelegate {
    func didTapCloseButton(sender: DashboardSignInBannerView) {
        output.viewDidHideSignInBanner()
    }

    func didTapSignInButton(sender: DashboardSignInBannerView) {
        output.viewDidTriggerSignIn()
    }
}
// swiftlint:enable file_length
