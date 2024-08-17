import Humidity
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
// swiftlint:disable file_length
import UIKit

class DashboardViewController: UIViewController {
    // Configuration
    var output: DashboardViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }

    var viewModels: [CardsViewModel] = [] {
        didSet {
            updateUI()
        }
    }

    var dashboardType: DashboardType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
            reloadCollectionView(redrawLayout: true)
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

    var showSignInButtonOnNoSensorView: Bool {
        switch (isAuthorized, userSignedInOnce) {
        case (true, _):
            return false
        case (false, true):
            return true
        case (false, false):
            return false
        }
    }

    var userSignedInOnce: Bool = false {
        didSet {
            noSensorView.showSignInButtonOnNoSensorView = showSignInButtonOnNoSensorView
        }
    }

    var isAuthorized: Bool = false {
        didSet {
            noSensorView.showSignInButtonOnNoSensorView = showSignInButtonOnNoSensorView
        }
    }

    var shouldShowSignInBanner: Bool = false {
        didSet {
            showNoSignInBannerIfNeeded()
        }
    }

    private func cell(
        collectionView: UICollectionView,
        indexPath: IndexPath,
        viewModel: CardsViewModel
    ) -> UICollectionViewCell? {
        switch dashboardType {
        case .image:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cellId",
                for: indexPath
            ) as? DashboardImageCell
            cell?.configure(with: viewModel, measurementService: measurementService)
            cell?.restartAlertAnimation(for: viewModel)
            cell?.delegate = self
            cell?.resetMenu(menu: cardContextMenuOption(for: indexPath.item))
            return cell
        case .simple:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cellIdPlain",
                for: indexPath
            ) as? DashboardPlainCell
            cell?.configure(with: viewModel, measurementService: measurementService)
            cell?.restartAlertAnimation(for: viewModel)
            cell?.delegate = self
            cell?.resetMenu(menu: cardContextMenuOption(for: indexPath.item))
            return cell
        case .none:
            return nil
        }
    }

    // UI
    private lazy var noSensorView: NoSensorView = {
        let view = NoSensorView()
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.delegate = self
        view.showSignInButtonOnNoSensorView = showSignInButtonOnNoSensorView
        return view
    }()

    // Header View
    // Ruuvi Logo
    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.ruuviLogo.image.withRenderingMode(.alwaysTemplate),
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.logoTintColor.color
        return iv
    }()

    // Action Buttons
    private lazy var menuButton: UIButton = {
        let button = UIButton()
        button.tintColor = RuuviColor.menuTintColor.color
        let menuImage = RuuviAsset.baselineMenuWhite48pt.image
        button.setImage(menuImage, for: .normal)
        button.setImage(menuImage, for: .highlighted)
        button.backgroundColor = .clear
        button.addTarget(
            self,
            action: #selector(handleMenuButtonTap),
            for: .touchUpInside
        )
        return button
    }()

    private lazy var viewButton: RuuviContextMenuButton =
        .init(
            menu: viewToggleMenuOptions(),
            titleColor: RuuviColor.dashboardIndicator.color,
            title: RuuviLocalization.view,
            icon: RuuviAsset.arrowDropDown.image,
            iconTintColor: RuuviColor.logoTintColor.color,
            iconSize: .init(width: 14, height: 14),
            preccedingIcon: false
        )

    // BODY
    private lazy var dashboardSignInBannerView: DashboardSignInBannerView = {
        let view = DashboardSignInBannerView()
        view.delegate = self
        return view
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.dragDelegate = self
        cv.dropDelegate = self
        cv.alwaysBounceVertical = true
        cv.refreshControl = refresher
        return cv
    }()

    private lazy var refresher: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = RuuviColor.tintColor.color
        rc.layer.zPosition = -1
        rc.alpha = 0
        rc.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        return rc
    }()

    private var showSignInBannerConstraint: NSLayoutConstraint!
    private var hideSignInBannerConstraint: NSLayoutConstraint!

    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32

    private var appDidBecomeActiveToken: NSObjectProtocol?

    private var isListRefreshable: Bool = true
    private var isRefreshing: Bool = false

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
}

// MARK: - View lifecycle

extension DashboardViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        configureRestartAnimationsOnAppDidBecomeActive()
        localize()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadCollectionView()
        navigationController?.makeTransparent()
        output.viewWillAppear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppUtility.lockOrientation(.all)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.resetStyleToDefault()
        output.viewWillDisappear()
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator:
        UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        reloadCollectionView(redrawLayout: true)
    }
}

private extension DashboardViewController {
    @objc func handleMenuButtonTap() {
        output.viewDidTriggerMenu()
    }

    private func reloadCollectionView(redrawLayout: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            if redrawLayout {
                guard let self else { return }
                let flowLayout = createLayout()
                collectionView.setCollectionViewLayout(
                    flowLayout,
                    animated: false,
                    completion: { _ in
                        guard self.viewModels.count > 0 else { return }
                        let indexPath = IndexPath(item: 0, section: 0)
                        self.collectionView.scrollToItem(
                            at: indexPath,
                            at: .top,
                            animated: false
                        )
                    }
                )
            }
            self?.collectionView.reloadWithoutAnimation()
        }
    }

    @objc func didPullToRefresh() {
        guard !isRefreshing
        else {
            refresher.endRefreshing()
            return
        }
        refresher.fadeIn()
        isRefreshing = true
        output.viewDidTriggerPullToRefresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) { [weak self] in
            self?.refresher.endRefreshing()
            self?.isRefreshing = false
            self?.refresher.fadeOut()
        }
    }
}

extension DashboardViewController {
    // swiftlint:disable:next function_body_length
    private func viewToggleMenuOptions() -> UIMenu {
        // Card Type
        let imageViewTypeAction = UIAction(title: RuuviLocalization.imageCards) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .image)
            self?.reloadCollectionView(redrawLayout: true)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let simpleViewTypeAction = UIAction(title: RuuviLocalization.simpleCards) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .simple)
            self?.reloadCollectionView(redrawLayout: true)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        simpleViewTypeAction.state = dashboardType == .simple ? .on : .off
        imageViewTypeAction.state = dashboardType == .image ? .on : .off

        let cardTypeMenu = UIMenu(
            title: RuuviLocalization.cardType,
            options: .displayInline,
            children: [
                imageViewTypeAction, simpleViewTypeAction
            ]
        )

        // Card action
        let openSensorViewAction = UIAction(title: RuuviLocalization.openSensorView) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .card)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let openHistoryViewAction = UIAction(title: RuuviLocalization.openHistoryView) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .chart)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        openSensorViewAction.state = dashboardTapActionType == .card ? .on : .off
        openHistoryViewAction.state = dashboardTapActionType == .chart ? .on : .off

        let cardActionMenu = UIMenu(
            title: RuuviLocalization.cardAction,
            options: .displayInline,
            children: [
                openSensorViewAction, openHistoryViewAction
            ]
        )

        // Sensor ordering
        let resetSensorSortingOrderAction = UIAction(
            title: RuuviLocalization.resetOrder
        ) {
            [weak self] _ in
            self?.output.viewDidResetManualSorting()
        }
        resetSensorSortingOrderAction.state = .off

        let resetSensorSortingOrderMenu = UIMenu(
            title: RuuviLocalization.ordering,
            options: .displayInline,
            children: [
                resetSensorSortingOrderAction
            ]
        )

        var menuItems: [UIMenuElement] = [
            cardTypeMenu,
            cardActionMenu,
        ]

        if dashboardSortingType == .manual {
            menuItems.append(resetSensorSortingOrderMenu)
        }

        return UIMenu(
            title: "",
            children: menuItems
        )
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func cardContextMenuOption(for index: Int) -> UIMenu {
        let fullImageViewAction = UIAction(title: RuuviLocalization.fullImageView) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerOpenCardImageView(for: viewModel)
            }
        }

        let historyViewAction = UIAction(title: RuuviLocalization.historyView) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChart(for: viewModel)
            }
        }

        let settingsAction = UIAction(title: RuuviLocalization.settingsAndAlerts) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerSettings(for: viewModel)
            }
        }

        let changeBackgroundAction = UIAction(title: RuuviLocalization.changeBackground) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChangeBackground(for: viewModel)
            }
        }

        let renameAction = UIAction(title: RuuviLocalization.rename) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerRename(for: viewModel)
            }
        }

        let shareSensorAction = UIAction(title: RuuviLocalization.TagSettings.shareButton) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerShare(for: viewModel)
            }
        }

        let moveUpAction = UIAction(title: RuuviLocalization.moveUp) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                let moveToIndex = index-1
                guard moveToIndex >= 0 else { return }
                self?.moveItem(viewModel, from: index, to: moveToIndex)
            }
        }

        let moveDownAction = UIAction(title: RuuviLocalization.moveDown) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                guard let sSelf = self else { return }
                let moveToIndex = index+1
                guard moveToIndex < sSelf.viewModels.count else { return }
                self?.moveItem(viewModel, from: index, to: moveToIndex)
            }
        }

        let removeSensorAction = UIAction(title: RuuviLocalization.remove) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerRemove(for: viewModel)
            }
        }

        var contextMenuActions: [UIAction] = [
            fullImageViewAction,
            historyViewAction,
            settingsAction,
            changeBackgroundAction,
            renameAction,
        ]

        // Add sensor move up and down action only if there are at least two sensors.
        // Do not show move up button for first time, and move down button for last item.
        if viewModels.count >= 1 {

          if index == 0 {
              contextMenuActions += [
                  moveDownAction,
              ]
          } else if index == viewModels.count - 1 {
              contextMenuActions += [
                  moveUpAction,
              ]
          } else {
              contextMenuActions += [
                  moveUpAction,
                  moveDownAction,
              ]
          }
        }

        let viewModel = viewModels[index]
        if let canShare = viewModel.canShareTag.value,
           canShare {
            contextMenuActions.append(shareSensorAction)
        }

        contextMenuActions.append(removeSensorAction)

        return UIMenu(title: "", children: contextMenuActions)
    }

  private func moveItem( _ item: CardsViewModel, from index: Int, to: Int) {
      let sourceIndexPath = IndexPath(item: index, section: 0)
      let destinationIndexPath = IndexPath(item: to, section: 0)

      collectionView.performBatchUpdates({ [weak self] in
          guard let self else { return }
          self.viewModels.remove(at: sourceIndexPath.item)
          self.viewModels.insert(item, at: destinationIndexPath.item)
          collectionView.deleteItems(at: [sourceIndexPath])
          collectionView.insertItems(at: [destinationIndexPath])
      }, completion: nil)

      // Reset the menu item for source and destionation cell
      if let sourceCell = collectionView.cellForItem(
        at: sourceIndexPath
      ) as? DashboardCell {
          sourceCell.resetMenu(
            menu: cardContextMenuOption(
                for: sourceIndexPath.item
            )
          )
      }
      if let destinationCell = collectionView.cellForItem(
        at: destinationIndexPath
      ) as? DashboardCell {
          destinationCell.resetMenu(
            menu: cardContextMenuOption(
                for: destinationIndexPath.item
            )
          )
      }

      // Scroll to destination indexpath
      collectionView.scrollToItem(
        at: destinationIndexPath,
        at: .centeredVertically,
        animated: true
      )

      let macIds = viewModels.compactMap { $0.mac.value?.value }
      output.viewDidReorderSensors(with: .manual, orderedIds: macIds)
    }

    private func showNoSignInBannerIfNeeded() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                guard let sSelf = self else { return }
                sSelf.dashboardSignInBannerView.alpha = sSelf.shouldShowSignInBanner ? 1 : 0

                if sSelf.shouldShowSignInBanner {
                    NSLayoutConstraint.deactivate([
                        sSelf.hideSignInBannerConstraint
                    ])
                    NSLayoutConstraint.activate([
                        sSelf.showSignInBannerConstraint
                    ])
                } else {
                    NSLayoutConstraint.deactivate([
                        sSelf.showSignInBannerConstraint
                    ])
                    NSLayoutConstraint.activate([
                        sSelf.hideSignInBannerConstraint
                    ])
                }
                sSelf.view.layoutIfNeeded()
            })
        }
    }
}

private extension DashboardViewController {
    func setUpUI() {
        updateNavBarTitleFont()
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
    }

    func updateNavBarTitleFont() {
        navigationController?.navigationBar.titleTextAttributes =
            [NSAttributedString.Key.font: UIFont.Muli(.bold, size: 18)]
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.dashboardBG.color

        view.addSubview(noSensorView)
        noSensorView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: view.safeBottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: 12,
                left: 12,
                bottom: 12,
                right: 12
            )
        )
        noSensorView.isHidden = true
    }

    func setUpHeaderView() {
        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(menuButton)
        menuButton.anchor(
            top: leftBarButtonView.topAnchor,
            leading: leftBarButtonView.leadingAnchor,
            bottom: leftBarButtonView.bottomAnchor,
            trailing: nil,
            padding: .init(top: 0, left: 0, bottom: 0, right: 0),
            size: .init(width: 32, height: 32)
        )

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: menuButton.trailingAnchor,
            bottom: nil,
            trailing: leftBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 8, bottom: 0, right: 0),
            size: .init(width: 110, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        let rightBarButtonView = UIView(color: .clear)
        rightBarButtonView.addSubview(viewButton)
        viewButton.anchor(
            top: rightBarButtonView.topAnchor,
            leading: rightBarButtonView.leadingAnchor,
            bottom: rightBarButtonView.bottomAnchor,
            trailing: rightBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 4),
            size: .init(
                width: 0,
                height: 32
            )
        )

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    func setUpContentView() {

        view.addSubview(dashboardSignInBannerView)
        dashboardSignInBannerView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )
        dashboardSignInBannerView.alpha = 0

        view.addSubview(collectionView)
        collectionView.anchor(
            top: nil,
            leading: view.safeLeftAnchor,
            bottom: view.bottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: 0,
                left: 12,
                bottom: 0,
                right: 12
            )
        )
        showSignInBannerConstraint = collectionView.topAnchor.constraint(
            equalTo: dashboardSignInBannerView.bottomAnchor, constant: 8
        )
        hideSignInBannerConstraint = collectionView.topAnchor.constraint(
            equalTo: view.safeTopAnchor,
            constant: 12
        )
        hideSignInBannerConstraint.isActive = true

        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(DashboardImageCell.self, forCellWithReuseIdentifier: "cellId")
        collectionView.register(DashboardPlainCell.self, forCellWithReuseIdentifier: "cellIdPlain")
    }

    // swiftlint:disable:next function_body_length
    func createLayout() -> UICollectionViewLayout {
        var itemEstimatedHeight: CGFloat = 144
        switch dashboardType {
        case .image:
            itemEstimatedHeight = GlobalHelpers.isDeviceTablet() ? 170 : 144
        case .simple:
            itemEstimatedHeight = GlobalHelpers.isDeviceTablet() ? 110 : 90
        default:
            break
        }

        let sectionProvider = { (
            _: Int,
            _: NSCollectionLayoutEnvironment
        )
            -> NSCollectionLayoutSection? in
        let widthMultiplier = GlobalHelpers.isDeviceTablet() ?
            (!GlobalHelpers.isDeviceLandscape() ? 0.5 : 0.3333) :
            (GlobalHelpers.isDeviceLandscape() ? 0.5 : 1.0)

        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(widthMultiplier),
            heightDimension: .absolute(itemEstimatedHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let itemHorizontalSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 6 : 4
        item.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: itemHorizontalSpacing,
            bottom: 0,
            trailing: itemHorizontalSpacing
        )

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(itemEstimatedHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupSize, subitems: [item]
        )

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = GlobalHelpers.isDeviceTablet() ? 12 : 8
        section.contentInsets = NSDirectionalEdgeInsets(
            top: 0,
            leading: 0,
            bottom: 12,
            trailing: 0
        )
        return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider,
            configuration: config
        )
        return layout
    }

    private func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.reloadCollectionView()
            }
    }

    // MARK: Drag and Drop
    private func dragPreviewParameters(
        for cell: UICollectionViewCell
    ) -> UIDragPreviewParameters? {
        let previewParameters = UIDragPreviewParameters()
        let path = UIBezierPath(
            roundedRect: cell.contentView.frame,
            cornerRadius: 8.0
        )
        previewParameters.visiblePath = path
        previewParameters.backgroundColor = .clear
        return previewParameters
    }
}

extension DashboardViewController: UICollectionViewDataSource {
    func collectionView(
        _: UICollectionView,
        numberOfItemsInSection _: Int
    ) -> Int {
        viewModels.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = cell(
            collectionView: collectionView,
            indexPath: indexPath,
            viewModel: viewModels[indexPath.item]
        )
        else {
            fatalError()
        }
        return cell
    }
}

extension DashboardViewController: UICollectionViewDelegate {

    func collectionView(
        _: UICollectionView,
        didSelectItemAt indexPath: IndexPath
    ) {
        let viewModel = viewModels[indexPath.item]
        output.viewDidTriggerDashboardCard(for: viewModel)
    }

    func collectionView(
        _: UICollectionView,
        willDisplay cell: UICollectionViewCell,
        forItemAt indexPath: IndexPath
    ) {
        guard viewModels.count > 0,
              indexPath.item < viewModels.count else { return }
        let viewModel = viewModels[indexPath.item]
        if let cell = cell as? DashboardImageCell {
            cell.restartAlertAnimation(for: viewModel)
        } else if let cell = cell as? DashboardPlainCell {
            cell.restartAlertAnimation(for: viewModel)
        }
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

    func scrollViewDidEndScrollingAnimation(_: UIScrollView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        isListRefreshable = true
    }
}

// MARK: UICollectionViewDragDelegate
extension DashboardViewController: UICollectionViewDragDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        itemsForBeginning session: UIDragSession,
        at indexPath: IndexPath
    ) -> [UIDragItem] {
        guard viewModels.count > 1 else { return [] }
        let item = viewModels[indexPath.item]
        let itemProvider = NSItemProvider(object: item as CardsViewModel)
        let dragItem = UIDragItem(itemProvider: itemProvider)
        dragItem.localObject = item
        return [dragItem]
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dragPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        return dragPreviewParameters(for: cell)
    }
}

// MARK: UICollectionViewDropDelegate
extension DashboardViewController: UICollectionViewDropDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        dropSessionDidUpdate session: UIDropSession,
        withDestinationIndexPath destinationIndexPath: IndexPath?
    ) -> UICollectionViewDropProposal {
        if collectionView.hasActiveDrag {
            return UICollectionViewDropProposal(
                operation: .move,
                intent: .insertAtDestinationIndexPath
            )
        }
        return UICollectionViewDropProposal(operation: .forbidden)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        performDropWith coordinator: UICollectionViewDropCoordinator
    ) {
        let destinationIndexPath: IndexPath

        if let indexPath = coordinator.destinationIndexPath {
            destinationIndexPath = indexPath
        } else {
            let row = collectionView.numberOfItems(inSection: 0)
            destinationIndexPath = IndexPath(row: row, section: 0)
        }

        guard destinationIndexPath.row < viewModels.count else { return }

        if coordinator.proposal.operation == .move {
            reorderItems(
                coordinator,
                destinationIndexPath: destinationIndexPath,
                collectionView: collectionView
            )
        }
    }

    func reorderItems(
        _ coordinator: UICollectionViewDropCoordinator,
        destinationIndexPath: IndexPath, collectionView: UICollectionView
    ) {
        guard let item = coordinator.items.first,
              let sourceIndexPath = item.sourceIndexPath,
              let dragItem = item.dragItem.localObject as? CardsViewModel else {
            return
        }

        collectionView.performBatchUpdates({ [weak self] in
            guard let self else { return }
            self.viewModels.remove(at: sourceIndexPath.item)
            self.viewModels.insert(dragItem, at: destinationIndexPath.item)
            collectionView.deleteItems(at: [sourceIndexPath])
            collectionView.insertItems(at: [destinationIndexPath])
        }, completion: nil)

        coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)

        let macIds = viewModels.compactMap { $0.mac.value?.value }
        output.viewDidReorderSensors(with: .manual, orderedIds: macIds)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        dropPreviewParametersForItemAt indexPath: IndexPath
    ) -> UIDragPreviewParameters? {
        guard let cell = collectionView.cellForItem(at: indexPath) else { return nil }
        return dragPreviewParameters(for: cell)
    }
}

// MARK: - DashboardViewInput

extension DashboardViewController: DashboardViewInput {
    func applyUpdate(to viewModel: CardsViewModel) {
        guard isListRefreshable
        else {
            return
        }

        if let index = viewModels.firstIndex(where: { vm in
            vm.luid.value != nil && vm.luid.value == viewModel.luid.value ||
                vm.mac.value != nil && vm.mac.value == viewModel.mac.value
        }) {
            let indexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView
                .cellForItem(at: indexPath) as? DashboardImageCell {
                cell.configure(
                    with: viewModel, measurementService: measurementService
                )
                cell.restartAlertAnimation(for: viewModel)
            } else if let cell = collectionView
                .cellForItem(at: indexPath) as? DashboardPlainCell {
                cell.configure(
                    with: viewModel, measurementService: measurementService
                )
                cell.restartAlertAnimation(for: viewModel)
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

    func showNoSensorsAddedMessage(show: Bool) {
        noSensorView.updateView(
            showSignInButtonOnNoSensorView: showSignInButtonOnNoSensorView
        )
        noSensorView.isHidden = !show
        collectionView.isHidden = show
    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {
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

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
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

    func showSensorNameRenameDialog(
        for viewModel: CardsViewModel,
        sortingType: DashboardSortingType
    ) {
        let defaultName = GlobalHelpers.ruuviTagDefaultName(
            from: viewModel.mac.value?.mac,
            luid: viewModel.luid.value?.value
        )
        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
            message: sortingType == .alphabetical ?
                RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text : nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            alertTextField.text = (defaultName == viewModel.name.value) ? nil : viewModel.name.value
            alertTextField.placeholder = defaultName
            tagNameTextField = alertTextField
        }
        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            if let name = tagNameTextField.text, !name.isEmpty {
                output.viewDidRenameTag(to: name, viewModel: viewModel)
            } else {
                output.viewDidRenameTag(to: defaultName, viewModel: viewModel)
            }
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    func showSensorSortingResetConfirmationDialog() {
        let message = RuuviLocalization.resetOrderConfirmation
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        let cancelTitle = RuuviLocalization.cancel
        alert.addAction(
            UIAlertAction(
                title: cancelTitle,
                style: .cancel,
                handler: nil
            )
        )

        let confirmTitle = RuuviLocalization.confirm
        alert.addAction(
            UIAlertAction(
                title: confirmTitle,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidReorderSensors(
                        with: .alphabetical, orderedIds: []
                    )
                }
            )
        )
        present(alert, animated: true)
    }
}

extension DashboardViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        guard isViewLoaded
        else {
            return
        }
        reloadCollectionView()
    }
}

extension DashboardViewController: DashboardCellDelegate {
    func didTapAlertButton(for viewModel: CardsViewModel) {
        output.viewDidTriggerSettings(for: viewModel)
    }
}

extension DashboardViewController: NoSensorViewDelegate {
    func didTapSignInButton(sender _: NoSensorView) {
        output.viewDidTriggerSignIn()
    }

    func didTapAddSensorButton(sender _: NoSensorView) {
        output.viewDidTriggerAddSensors()
    }

    func didTapBuySensorButton(sender _: NoSensorView) {
        output.viewDidTriggerBuySensors()
    }
}

private extension DashboardViewController {
    func updateUI() {
        showNoSensorsAddedMessage(show: viewModels.isEmpty)
        collectionView.reloadWithoutAnimation()
    }
}

// MARK: - UITextFieldDelegate

extension DashboardViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,

        replacementString string: String
    ) -> Bool {
        guard let text = textField.text
        else {
            return true
        }
        let limit = text.utf16.count + string.utf16.count - range.length
        if textField == tagNameTextField {
            if limit <= tagNameCharaterLimit {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
}

// MARK: - DashboardSignInBannerViewDelegate
extension DashboardViewController: DashboardSignInBannerViewDelegate {

    func didTapCloseButton(sender: DashboardSignInBannerView) {
        output.viewDidHideSignInBanner()
    }

    func didTapSignInButton(sender _: DashboardSignInBannerView) {
        output.viewDidTriggerSignIn()
    }
}
