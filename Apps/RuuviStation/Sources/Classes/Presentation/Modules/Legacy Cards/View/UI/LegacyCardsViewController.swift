// swiftlint:disable file_length
import Humidity
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
import UIKit
import Combine

// MARK: - Diffable Data Source Configuration
enum CardSection {
    case main
}

class LegacyCardsViewController: UIViewController {
    // Configuration
    var output: LegacyCardsViewOutput!
    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }

    var viewModels: [LegacyCardsViewModel] = [] {
        didSet {
            updateSnapshot(animated: true, forceReload: true)
        }
    }

    var scrollIndex: Int = 0
    var isRefreshing: Bool = false {
        didSet {
            if isRefreshing {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    private var currentPage: Int = 0 {
        didSet {
            setArrowButtonsVisibility(with: currentPage)
        }
    }

    private static let reuseIdentifier: String = "reuseIdentifier"

    // MARK: - Diffable Data Source
    private var dataSource: UICollectionViewDiffableDataSource<CardSection, LegacyCardsViewModel>!
    private var isUserScrolling: Bool = false
    private var pendingScrollIndex: Int?

    func configureCell(
        collectionView: UICollectionView,
        indexPath: IndexPath,
        viewModel: LegacyCardsViewModel
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.reuseIdentifier,
            for: indexPath
        ) as? LegacyCardsLargeImageCell
        cell?.configure(with: viewModel, measurementService: measurementService)
        return cell ?? UICollectionViewCell()
    }

    private func setupDataSource() {
        dataSource = UICollectionViewDiffableDataSource<CardSection, LegacyCardsViewModel>(
            collectionView: collectionView
        ) { [weak self] collectionView, indexPath, viewModel in
            self?.configureCell(collectionView: collectionView, indexPath: indexPath, viewModel: viewModel)
        }
    }

    private func updateSnapshot(animated: Bool, forceReload: Bool = false) {
        // Don't update if user is actively scrolling to prevent jumps
        guard !isUserScrolling else {
            return
        }

        if dataSource == nil {
            setupDataSource()
        }

        var snapshot = NSDiffableDataSourceSnapshot<CardSection, LegacyCardsViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels)

        // Force reload of all items if requested
        if forceReload {
            if #available(iOS 15.0, *) {
                snapshot.reconfigureItems(viewModels)
            } else {
                snapshot.reloadItems(viewModels)
            }
        }

        dataSource.apply(snapshot, animatingDifferences: animated) { [weak self] in
            // Handle any pending scroll after the snapshot is applied
            if let pendingIndex = self?.pendingScrollIndex {
                self?.pendingScrollIndex = nil
                self?.scrollToIndexAfterUpdate(pendingIndex)
            }
        }
    }

    private func scrollToIndexAfterUpdate(_ index: Int) {
        guard index < viewModels.count else { return }
        currentPage = index
        collectionView.scrollTo(index: index, animated: false)
    }

    // Force refresh all visible cells - useful when data has changed but objects are the same
    private func forceRefreshVisibleCells() {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        for indexPath in visibleIndexPaths {
            if let cell = collectionView.cellForItem(at: indexPath) as? LegacyCardsLargeImageCell,
               indexPath.item < viewModels.count {
                cell.configure(with: viewModels[indexPath.item], measurementService: measurementService)
            }
        }
    }

    func applySnapshot() {
        currentPage = scrollIndex
        pendingScrollIndex = scrollIndex
        updateSnapshot(animated: false, forceReload: true)
    }

    private var appDidBecomeActiveToken: NSObjectProtocol?

    // Base
    private lazy var cardBackgroundView = CardsBackgroundView()
    private lazy var chartViewBackground = UIView(color: RuuviColor.graphBGColor.color)

    // Header View
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

    private lazy var alertButton: RuuviCustomButton = {
        let button = RuuviCustomButton(icon: nil)
        button.backgroundColor = .clear
        return button
    }()

    /// This button is used to be able to tap the alert button when
    /// the alert icon is blinking.
    private lazy var alertButtonHidden: UIButton = {
        let button = UIButton()
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(alertButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var chartButton: RuuviCustomButton = {
        let button = RuuviCustomButton(icon: RuuviAsset.iconChartsButton.image)
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(chartButtonDidTap)
            )
        )
        return button
    }()

    private lazy var settingsButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: RuuviAsset.baselineSettingsWhite48pt.image,
            iconSize: .init(width: 26, height: 25)
        )
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(settingsButtonDidTap)
            )
        )
        return button
    }()

    // BODY
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
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.extraBold, size: 20)
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.isPagingEnabled = true
        cv.alwaysBounceVertical = false
        cv.delegate = self
        cv.register(
            LegacyCardsLargeImageCell.self,
            forCellWithReuseIdentifier: Self.reuseIdentifier
        )
        return cv
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        return ai
    }()

    private var currentVisibleCancellables = Set<AnyCancellable>()
    private var currentVisibleItem: LegacyCardsViewModel? {
        didSet {
            bindCurrentVisibleItem()
            updateTopActionButtonVisibility()
        }
    }

    private var isChartsShowing: Bool = false
    private var previousAlertState: String?

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
}

// MARK: - View lifecycle

extension LegacyCardsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        setupDataSource()
        configureGestureViews()
        localize()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.makeTransparent()
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.resetStyleToDefault()
        output.viewWillDisappear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restartAnimations()
        output.viewDidAppear()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Scroll to current Item after the orientation change.
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let sSelf = self else { return }
            let flowLayout = sSelf.createLayout()
            sSelf.collectionView.setCollectionViewLayout(
                flowLayout,
                animated: false,
                completion: { _ in
                    guard sSelf.viewModels.count > 0 else { return }
                    if sSelf.currentPage < sSelf.viewModels.count {
                        sSelf.collectionView.scrollTo(index: sSelf.currentPage)
                    }
                }
            )
        })
    }
}

private extension LegacyCardsViewController {
    func setUpUI() {
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.primary.color

        view.addSubview(cardBackgroundView)
        cardBackgroundView.fillSuperview()

        view.addSubview(chartViewBackground)
        chartViewBackground.fillSuperview()
        chartViewBackground.alpha = 0
    }

    // swiftlint:disable:next function_body_length
    func setUpHeaderView() {
        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(backButton)
        backButton.anchor(
            top: leftBarButtonView.topAnchor,
            leading: leftBarButtonView.leadingAnchor,
            bottom: leftBarButtonView.bottomAnchor,
            trailing: nil,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0),
            size: .init(width: 48, height: 48)
        )

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: backButton.trailingAnchor,
            bottom: nil,
            trailing: leftBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 0),
            size: .init(width: 90, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        let rightBarButtonView = UIView(color: .clear)
        // Right action buttons
        rightBarButtonView.addSubview(alertButton)
        alertButton.anchor(
            top: rightBarButtonView.topAnchor,
            leading: rightBarButtonView.leadingAnchor,
            bottom: rightBarButtonView.bottomAnchor,
            trailing: nil
        )
        alertButton.centerYInSuperview()

        rightBarButtonView.addSubview(alertButtonHidden)
        alertButtonHidden.match(view: alertButton)

        rightBarButtonView.addSubview(chartButton)
        chartButton.anchor(
            top: nil,
            leading: alertButton.trailingAnchor,
            bottom: nil,
            trailing: nil
        )
        chartButton.centerYInSuperview()

        rightBarButtonView.addSubview(settingsButton)
        settingsButton.anchor(
            top: nil,
            leading: chartButton.trailingAnchor,
            bottom: nil,
            trailing: rightBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: -14)
        )
        settingsButton.centerYInSuperview()

        let titleView = UIView(
            color: .clear
        )
        titleView.addSubview(activityIndicator)
        activityIndicator.fillSuperview()

        navigationItem.titleView = titleView
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    func setUpContentView() {
        let swipeToolbarView = UIView(color: .clear)
        // Arrow buttons should stay above of collection view
        swipeToolbarView.addSubview(cardLeftArrowButton)
        cardLeftArrowButton.anchor(
            top: swipeToolbarView.topAnchor,
            leading: swipeToolbarView.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 6, left: 4, bottom: 0, right: 0)
        )

        swipeToolbarView.addSubview(cardRightArrowButton)
        cardRightArrowButton.anchor(
            top: swipeToolbarView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: swipeToolbarView.trailingAnchor,
            padding: .init(top: 4, left: 0, bottom: 0, right: 4)
        )

        swipeToolbarView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: swipeToolbarView.topAnchor,
            leading: cardLeftArrowButton.trailingAnchor,
            bottom: swipeToolbarView.bottomAnchor,
            trailing: cardRightArrowButton.leadingAnchor,
            padding: .init(top: 8, left: 8, bottom: 6, right: 8)
        )

        view.addSubview(swipeToolbarView)
        swipeToolbarView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )

        view.addSubview(collectionView)
        collectionView.anchor(
            top: swipeToolbarView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: view.safeBottomAnchor,
            trailing: view.safeRightAnchor
        )
    }

    func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (
            _: Int,
            _: NSCollectionLayoutEnvironment
        )
            -> NSCollectionLayoutSection? in
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider,
            configuration: config
        )
        return layout
    }

    private func configureGestureViews() {
        configureRestartAnimationsOnAppDidBecomeActive()
    }

    private func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.restartAnimations()
            }
    }
}

extension LegacyCardsViewController: UICollectionViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isUserScrolling = true
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        isUserScrolling = false
        let xPoint = scrollView.contentOffset.x + scrollView.frame.size.width / 2
        let yPoint = scrollView.frame.size.height / 2
        let center = CGPoint(x: xPoint, y: yPoint)
        if let currentIndexPath = collectionView.indexPathForItem(at: center) {
            performPostScrollActions(with: currentIndexPath.row)
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isUserScrolling = false
    }
}

extension LegacyCardsViewController {
    @objc private func backButtonDidTap() {
        // TODO: Handle the case when chart visible and sync ongoing.
        if isChartsShowing {
            guard let viewModel = currentVisibleItem
            else {
                return
            }
            output.viewDidTriggerDismissChart(
                for: viewModel,
                dismissParent: true
            )
        } else {
            output.viewShouldDismiss()
        }
    }

    @objc private func alertButtonDidTap() {
        guard let viewModel = currentVisibleItem
        else {
            return
        }
        output.viewDidTriggerSettings(for: viewModel)
    }

    @objc private func chartButtonDidTap() {
        guard let viewModel = currentVisibleItem
        else {
            return
        }

        if isChartsShowing {
            output.viewDidTriggerDismissChart(
                for: viewModel,
                dismissParent: false
            )
        } else {
            output.viewDidTriggerShowChart(for: viewModel)
        }
    }

    func showChart(module: UIViewController) {
        if !isViewLoaded {
            loadViewIfNeeded()
        }

        chartButton.image = RuuviAsset.iconCardsButton.image
        chartViewBackground.alpha = 1
        collectionView.isHidden = true
        module.willMove(toParent: self)
        addChild(module)
        view.insertSubview(module.view, aboveSubview: collectionView)
        module.view.match(view: collectionView)
        module.didMove(toParent: self)
        isChartsShowing = true
        output.showingChart = true
    }

    func dismissChart() {
        chartButton.image = RuuviAsset.iconChartsButton.image
        chartViewBackground.alpha = 0
        children.forEach {
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        }
        isChartsShowing = false
        collectionView.isHidden = false
        output.showingChart = false
    }

    @objc private func settingsButtonDidTap() {
        guard let viewModel = currentVisibleItem
        else {
            return
        }
        navigationController?.setNavigationBarHidden(false, animated: false)
        output.viewDidTriggerSettings(for: viewModel)
    }

    @objc private func cardLeftArrowButtonDidTap() {
        guard viewModels.count > 0 else { return }
        let scrollToPageIndex = currentPage - 1
        if scrollToPageIndex >= 0, scrollToPageIndex < viewModels.count {
            performPostScrollActions(with: scrollToPageIndex, scroll: true)
        }
    }

    @objc private func cardRightArrowButtonDidTap() {
        guard viewModels.count > 0 else { return }
        let scrollToPageIndex = currentPage + 1
        if scrollToPageIndex >= 0, scrollToPageIndex < viewModels.count {
            performPostScrollActions(with: scrollToPageIndex, scroll: true)
        }
    }
}

// MARK: - LegacyCardsViewInput

extension LegacyCardsViewController: LegacyCardsViewInput {
    func viewShouldDismiss() {
        output.viewShouldDismiss()
    }

    func applyUpdate(to viewModel: LegacyCardsViewModel) {
        // Find the view model in current snapshot and update it
        guard let index = viewModels.firstIndex(where: { vm in
            vm.luid != nil && vm.luid == viewModel.luid ||
                vm.mac != nil && vm.mac == viewModel.mac
        }) else { return }

        // Update the model in our array
        viewModels[index] = viewModel

        // Update the specific cell if visible
        let indexPath = IndexPath(item: index, section: 0)
        if let cell = collectionView.cellForItem(at: indexPath) as? LegacyCardsLargeImageCell {
            cell.configure(with: viewModel, measurementService: measurementService)
            restartAnimations()
            updateTopActionButtonVisibility()
        }

        // Apply snapshot update only if user is not scrolling
        if !isUserScrolling {
            var currentSnapshot = dataSource.snapshot()
            // For individual updates, we need to force reload the specific item
            if currentSnapshot.itemIdentifiers.contains(viewModel) {
                if #available(iOS 15.0, *) {
                    currentSnapshot.reconfigureItems([viewModel])
                } else {
                    currentSnapshot.reloadItems([viewModel])
                }
                dataSource.apply(currentSnapshot, animatingDifferences: true)
            } else {
                // If item not found in snapshot, do a full reload
                updateSnapshot(animated: true, forceReload: true)
            }
        }
    }

    func localize() {
        // No op.
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
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func scroll(to index: Int) {
        guard viewModels.count > 0,
              index < viewModels.count
        else {
            return
        }
        let viewModel = viewModels[index]
        currentVisibleItem = viewModel
        currentPage = index

        // If user is scrolling, defer the scroll operation
        if isUserScrolling {
            pendingScrollIndex = index
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
                guard let sSelf = self else { return }
                sSelf.collectionView.scrollTo(index: index, animated: false)
                sSelf.output.viewDidTriggerFirmwareUpdateDialog(for: viewModel)
                // Force refresh to ensure the scrolled-to cell displays the latest data
                sSelf.forceRefreshVisibleCells()
            }
        }

        restartAnimations()
    }

    func showKeepConnectionDialogChart(for viewModel: LegacyCardsViewModel) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogChart(for: viewModel)
        }))
        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionChart(to: viewModel)
        }))
        present(alert, animated: true)
    }

    func showKeepConnectionDialogSettings(for viewModel: LegacyCardsViewModel) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogSettings(for: viewModel)
        }))
        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionSettings(to: viewModel)
        }))
        present(alert, animated: true)
    }

    func showFirmwareUpdateDialog(for viewModel: LegacyCardsViewModel) {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog(for: viewModel)
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate(for: viewModel)
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: LegacyCardsViewModel) {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissFirmwareUpdateDialog(for: viewModel)
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate(for: viewModel)
        }))
        present(alert, animated: true)
    }

    func showReverseGeocodingFailed() {
        let message = RuuviLocalization.Cards.Error.ReverseGeocodingFailed.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    func showAlreadyLoggedInAlert(with email: String) {
        let message = RuuviLocalization.Cards.Alert.AlreadyLoggedIn.message(email)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}

extension LegacyCardsViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        guard isViewLoaded,
              let viewModel = currentVisibleItem
        else {
            return
        }
        applyUpdate(to: viewModel)
    }
}

extension LegacyCardsViewController {
    private func updateUI() {
        updateSnapshot(animated: true, forceReload: true)

        if scrollIndex < viewModels.count {
            let item = viewModels[scrollIndex]
            currentVisibleItem = item
        }
    }

    // swiftlint:disable:next function_body_length
    private func bindCurrentVisibleItem() {
        // Clear old subscriptions.
        currentVisibleCancellables.removeAll()

        guard let item = currentVisibleItem else { return }

        // 1) Observe name changes -> update UI
        item.$name
            .receive(on: RunLoop.main)
            .sink { [weak self] newName in
                self?.ruuviTagNameLabel.text = newName
            }
            .store(in: &currentVisibleCancellables)

        item.$background
            .receive(on: RunLoop.main)
            .sink { [weak self] background in
                self?.cardBackgroundView.setBackgroundImage(with: background)
            }
            .store(in: &currentVisibleCancellables)

        // 2) Observe all alert-state properties -> call restartAnimations()
        let alertMutedTillProperties = [
            item.$temperatureAlertMutedTill,
            item.$relativeHumidityAlertMutedTill,
            item.$pressureAlertMutedTill,
            item.$signalAlertMutedTill,
            item.$movementAlertMutedTill,
            item.$connectionAlertMutedTill,
            item.$carbonDioxideAlertMutedTill,
            item.$pMatter1AlertMutedTill,
            item.$pMatter25AlertMutedTill,
            item.$pMatter4AlertMutedTill,
            item.$pMatter10AlertMutedTill,
            item.$vocAlertMutedTill,
            item.$noxAlertMutedTill,
            item.$soundAlertMutedTill,
            item.$luminosityAlertMutedTill,
        ]

        for property in alertMutedTillProperties {
            property
                .sink { [weak self] _ in
                    self?.restartAnimations()
                }
                .store(in: &currentVisibleCancellables)
        }

        item.$alertState
            .sink { [weak self] _ in
                self?.restartAnimations()
            }
            .store(in: &currentVisibleCancellables)

        // 3) Observe properties that change top-action-button visibility
        item.$isChartAvailable
            .sink { [weak self] _ in
                self?.updateTopActionButtonVisibility()
            }
            .store(in: &currentVisibleCancellables)

        item.$isAlertAvailable
            .sink { [weak self] _ in
                self?.updateTopActionButtonVisibility()
            }
            .store(in: &currentVisibleCancellables)

        item.$isConnected
            .sink { [weak self] _ in
                self?.updateTopActionButtonVisibility()
            }
            .store(in: &currentVisibleCancellables)
    }
}

extension LegacyCardsViewController {

    // swiftlint:disable:next function_body_length
    private func restartAnimations() {
        let mutedTills = [
            currentVisibleItem?.temperatureAlertMutedTill,
            currentVisibleItem?.relativeHumidityAlertMutedTill,
            currentVisibleItem?.pressureAlertMutedTill,
            currentVisibleItem?.signalAlertMutedTill,
            currentVisibleItem?.movementAlertMutedTill,
            currentVisibleItem?.connectionAlertMutedTill,
            currentVisibleItem?.carbonDioxideAlertMutedTill,
            currentVisibleItem?.pMatter1AlertMutedTill,
            currentVisibleItem?.pMatter25AlertMutedTill,
            currentVisibleItem?.pMatter4AlertMutedTill,
            currentVisibleItem?.pMatter10AlertMutedTill,
            currentVisibleItem?.vocAlertMutedTill,
            currentVisibleItem?.noxAlertMutedTill,
            currentVisibleItem?.soundAlertMutedTill,
            currentVisibleItem?.luminosityAlertMutedTill,
        ]

        if mutedTills.first(where: { $0 != nil }) != nil {
            alertButton.image = RuuviAsset.iconAlertOff.image
            removeAlertAnimations(alpha: 0.5)
            return
        }

        if let state = currentVisibleItem?.alertState {
            switch state {
            case .empty:
                alertButton.image = RuuviAsset.iconAlertOff.image
                removeAlertAnimations(alpha: 0.5)
            case .registered:
                alertButton.image = RuuviAsset.iconAlertOn.image
                removeAlertAnimations()
            case .firing:
                alertButton.alpha = 1.0
                alertButton.image = RuuviAsset.iconAlertActive.image
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    UIView.animate(
                        withDuration: 0.5,
                        delay: 0,
                        options: [
                            .repeat,
                            .autoreverse,
                        ],
                        animations: { [weak self] in
                            self?.alertButton.alpha = 0.0
                        }
                    )
                }
            }
        } else {
            alertButton.image = nil
            removeAlertAnimations()
        }
    }

    func removeAlertAnimations(alpha: Double = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.alertButton.layer.removeAllAnimations()
            self?.alertButton.alpha = alpha
        }
    }

    private func updateTopActionButtonVisibility() {
        guard let viewModel = currentVisibleItem
        else {
            return
        }

        if let isChartAvaiable = viewModel.isChartAvailable {
            chartButton.isHidden = !isChartAvaiable
        } else {
            chartButton.isHidden = true
        }

        let type = viewModel.type
        switch type {
        case .ruuvi:
            if let isAlertAvailable = viewModel.isAlertAvailable {
                alertButton.isHidden = !isAlertAvailable
                alertButtonHidden.isUserInteractionEnabled = isAlertAvailable
            } else {
                alertButton.isHidden =
                    !viewModel.isConnected || viewModel.serviceUUID == nil
                alertButtonHidden.isUserInteractionEnabled =
                    viewModel.isConnected || viewModel.serviceUUID != nil
            }
        }
    }

    private func setArrowButtonsVisibility(hidden: Bool, animated: Bool) {
        if hidden {
            cardLeftArrowButton.fadeOut(animated: animated)
            cardRightArrowButton.fadeOut(animated: animated)
        } else {
            cardLeftArrowButton.fadeIn(animated: animated)
            cardRightArrowButton.fadeIn(animated: animated)
        }
    }

    private func setArrowButtonsVisibility(with index: Int) {
        if index == 0 {
            cardLeftArrowButton.fadeOut()
        } else {
            cardLeftArrowButton.fadeIn()
        }

        if index == viewModels.count - 1 {
            cardRightArrowButton.fadeOut()
        } else {
            cardRightArrowButton.fadeIn()
        }
    }

    private func performPostScrollActions(with index: Int, scroll: Bool = false) {
        let currentItem = viewModels[index]
        if isChartsShowing {
            output.viewDidTriggerNavigateChart(to: currentItem)
        } else {
            currentPage = index
            currentVisibleItem = currentItem
            restartAnimations()
            output.viewDidScroll(to: currentItem)
            output.viewDidTriggerFirmwareUpdateDialog(for: currentItem)

            if scroll {
                collectionView.scrollTo(index: index, animated: true)
            }
        }
    }
}
