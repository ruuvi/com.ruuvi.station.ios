import Humidity
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
// swiftlint:disable file_length
import UIKit
import Combine

@objc protocol MasonryLayoutDelegate: AnyObject {
    @objc optional func collectionView(
        _ collectionView: UICollectionView,
        heightForItemAt indexPath: IndexPath,
        with width: CGFloat
    ) -> CGFloat
}

// MARK: - MasonryLayout
// MARK: - MasonryLayout
class MasonryLayout: UICollectionViewLayout {

    var delegate: MasonryLayoutDelegate?
    // MARK: - Properties
    private let numberOfColumns: Int
    private let cellPadding: CGFloat

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    // Track which item is being dragged
    private var draggedItemIndexPath: IndexPath?
    private var draggedItemAttributes: UICollectionViewLayoutAttributes?

    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        let insets = collectionView.contentInset
        return collectionView.bounds.width - (insets.left + insets.right)
    }

    // MARK: - Initialization
    init(numberOfColumns: Int = 2, cellPadding: CGFloat = 4) {
        self.numberOfColumns = numberOfColumns
        self.cellPadding = cellPadding
        super.init()
    }

    required init?(coder: NSCoder) {
        self.numberOfColumns = 2
        self.cellPadding = 0
        super.init(coder: coder)
    }

    // MARK: - Layout Preparation
    override func prepare() {
        guard let collectionView = collectionView else { return }

        cache.removeAll(keepingCapacity: true)
        contentHeight = 0

        // Calculate column width
        let columnWidth = contentWidth / CGFloat(numberOfColumns)

        // Track the Y position for each column
        var xOffsets: [CGFloat] = []
        for column in 0..<numberOfColumns {
            xOffsets.append(CGFloat(column) * columnWidth)
        }

        var yOffsets = [CGFloat](repeating: 0, count: numberOfColumns)

        // Iterate through each item
        for item in 0..<collectionView.numberOfItems(inSection: 0) {
            let indexPath = IndexPath(item: item, section: 0)

            // Skip the dragged item as we'll handle it separately
            if indexPath == draggedItemIndexPath, let draggedAttributes = draggedItemAttributes {
                cache.append(draggedAttributes)
                continue
            }

            // Find the column with the shortest height
            var column = 0
            for index in 1..<numberOfColumns {
                if yOffsets[index] < yOffsets[column] {
                    column = index
                }
            }

            // Get the height for this cell
            let cellHeight = getCellHeight(for: indexPath, width: columnWidth)

            // Calculate the frame
            let xOffset = xOffsets[column]
            let yOffset = yOffsets[column]

            let frame = CGRect(
                x: xOffset + cellPadding,
                y: yOffset + cellPadding,
                width: columnWidth - (cellPadding * 2),
                height: cellHeight - (cellPadding * 2)
            )

            // Create the attributes
            let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
            attributes.frame = frame
            cache.append(attributes)

            // Update the content height and column heights
            contentHeight = max(contentHeight, frame.maxY + cellPadding)
            yOffsets[column] = frame.maxY + (cellPadding * 2)
        }
    }

    // MARK: - Private methods
    private func getCellHeight(for indexPath: IndexPath, width: CGFloat) -> CGFloat {
        return delegate?.collectionView?(
                    collectionView!,
                    heightForItemAt: indexPath,
                    with: width
                ) ?? 200 // Default height if no delegate method is implemented
    }

    // MARK: - Collection View Layout Methods
    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache.first(where: { $0.indexPath == indexPath })
    }

    // Reset cache when layout is invalidated
    override func invalidateLayout() {
        super.invalidateLayout()
        // We'll recalculate in prepare()
    }

    // MARK: - Dragging Support

    // Return true to make sure the layout updates during dragging
    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        return true
    }

    // This integrates with the native drag & drop system
    override func layoutAttributesForInteractivelyMovingItem(at indexPath: IndexPath, withTargetPosition position: CGPoint) -> UICollectionViewLayoutAttributes {
        let attributes = super.layoutAttributesForInteractivelyMovingItem(at: indexPath, withTargetPosition: position)

        // Calculate proper size for the dragged item
        let columnWidth = contentWidth / CGFloat(numberOfColumns)
        let cellHeight = getCellHeight(for: indexPath, width: columnWidth)

        // Keep the width consistent but use our calculated height
        attributes.frame = CGRect(
            x: position.x - columnWidth/2 + cellPadding,
            y: position.y - cellHeight/2 + cellPadding,
            width: columnWidth - (cellPadding * 2),
            height: cellHeight - (cellPadding * 2)
        )

        // Visual feedback for dragging
        attributes.alpha = 0.95
        attributes.zIndex = 99

        // Store attributes for the dragged item
        draggedItemIndexPath = indexPath
        draggedItemAttributes = attributes.copy() as? UICollectionViewLayoutAttributes

        return attributes
    }

    // Clear dragging state when done
    func clearDraggingState() {
        draggedItemIndexPath = nil
        draggedItemAttributes = nil
        invalidateLayout()
    }
}

private enum Section { case main }

class DashboardViewController: UIViewController {
    // Configuration
    private let sizingCell = DashboardPlainCell()
    var output: DashboardViewOutput!
    var menuPresentInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var menuDismissInteractiveTransition: UIViewControllerInteractiveTransitioning!
    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }

    private var dataSource: UICollectionViewDiffableDataSource<Section, CardsViewModel>!
    var viewModels: [CardsViewModel] = [] {
        didSet {
            updateUI()
        }
    }
    private var ticker: AnyCancellable?

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

    var isRefreshing: Bool = false {
        didSet {
            if isRefreshing {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
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
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cellId",
                for: indexPath
            ) as? DashboardImageCell else { return nil }
//            viewModel.combinedPublisher()
//              .receive(on: DispatchQueue.main)
//              .sink { [weak self] _ in
//                  cell.configure(with: viewModel, measurementService: self?.measurementService)
//              }
//              .store(in: &cell.cancellables)
            viewModel.$alertState
              .receive(on: DispatchQueue.main)
              .sink { _ in
                  cell.restartAlertAnimation(for: viewModel)
              }
              .store(in: &cell.cancellables)
            cell.configure(with: viewModel, measurementService: measurementService)
            cell.restartAlertAnimation(for: viewModel)
            cell.delegate = self
            cell.resetMenu(menu: cardContextMenuOption(for: indexPath.item))
            return cell
        case .simple:
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cellIdPlain",
                for: indexPath
            ) as? DashboardPlainCell else { return nil }
//            viewModel.combinedPublisher()
//              .receive(on: DispatchQueue.main)
//              .sink { [weak self] _ in
//                  cell.configure(with: viewModel, measurementService: self?.measurementService)
//              }
//              .store(in: &cell.cancellables)
            viewModel.$alertState
              .receive(on: DispatchQueue.main)
              .sink { _ in
                  cell.restartAlertAnimation(for: viewModel)
              }
              .store(in: &cell.cancellables)
            cell.configure(with: viewModel, measurementService: measurementService)
            cell.restartAlertAnimation(for: viewModel)
            cell.delegate = self
            cell.resetMenu(menu: cardContextMenuOption(for: indexPath.item))
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

    private lazy var menuButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: RuuviAsset.baselineMenuWhite48pt.image,
            tintColor: RuuviColor.menuTintColor.color,
            iconSize: .init(width: 36, height: 36),
            leadingPadding: 6,
            trailingPadding: 6
        )
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(handleMenuButtonTap)
            )
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
        let layout = MasonryLayout(numberOfColumns: 3, cellPadding: 4)
        layout.delegate = self
        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
//        cv.dataSource = self
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
        rc.addTarget(self, action: #selector(handleRefreshValueChanged), for: .valueChanged)
        return rc
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = RuuviColor.dashboardIndicator.color
        ai.hidesWhenStopped = true
        return ai
    }()

    private var showSignInBannerConstraint: NSLayoutConstraint!
    private var hideSignInBannerConstraint: NSLayoutConstraint!

    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32

    private var appDidBecomeActiveToken: NSObjectProtocol?

    private var isListRefreshable: Bool = true
    private var isPulling: Bool = false

    deinit {
        appDidBecomeActiveToken?.invalidate()
        ticker?.cancel()
    }
}

// MARK: - View lifecycle

extension DashboardViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        configureDiffableDataSource()      // A-1
        startGlobalTicker()                // A-5
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

    private func configureDiffableDataSource() {
        dataSource = UICollectionViewDiffableDataSource<Section, CardsViewModel>(
            collectionView: collectionView
        ) { [weak self] cv, indexPath, model -> UICollectionViewCell? in
            return self?.cell(collectionView: cv,
                               indexPath: indexPath,
                               viewModel: model)
        }
        applySnapshot(animating: false)
    }

    private func applySnapshot(animating: Bool = true) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, CardsViewModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(viewModels, toSection: .main)
        print("viewModels.count: \(viewModels.count)")
        dataSource.apply(snapshot, animatingDifferences: animating)
    }

    // MARK: ––––– A-5  1 Hz ticker updates only visible cells
    private func startGlobalTicker() {
        ticker = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.refreshVisibleCells()
            }
    }

    private func refreshVisibleCells() {
        collectionView.visibleCells.forEach { cell in
            guard let dashCell = cell as? DashboardCell,
                  let indexPath = collectionView.indexPath(for: cell),
                  indexPath.item < viewModels.count else { return }
            dashCell.restartAlertAnimation(for: viewModels[indexPath.item])
        }
    }

    func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0), // Item takes full width of its group
            heightDimension: .estimated(100) // ESTIMATED height, cell will self-size
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // Adjust columnCount to how many columns you want
        let columnCount = 2

        // Group to hold items horizontally (for columns)
        // The group's height is also estimated, as it depends on the tallest item in that "row"
        // for a true masonry, each column is independent.
        // For a simpler "waterfall" that fills row by row, this approach is a good start.
        // For true independent column masonry, you'd typically create a custom NSCollectionLayoutGroup.
        // However, a common approach is to make items in a group have estimated height
        // and let the layout engine arrange them.

        // This creates a group that effectively represents one "row" in the masonry.
        // For a more traditional masonry where columns are independent, you might need a custom layout subclass
        // or a more complex group structure. A simpler approach for "columns" is often to
        // have a group that spans the full width and contains multiple items side-by-side.

        // Let's define a group that represents a single column's width.
        // Then the section will lay these out.
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columnCount)),
            heightDimension: .estimated(100) // Group height is also estimated
        )

        // If you want items to be laid out vertically within each column before moving to the next:
        // This is a bit more complex with standard compositional layout for true masonry.
        // A common simplification is to have a horizontal group with 'columnCount' items.
        // The layout will try to fit them.

        // Simpler approach for multi-column:
        // Create a group that contains 'columnCount' items horizontally.
        let groupHorizontalSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .estimated(100) // Height is estimated
        )
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: groupHorizontalSize,
            subitem: item, // This item will be repeated 'columnCount' times
            count: columnCount
        )
        group.interItemSpacing = .fixed(0) // Spacing between items in the row (columns)

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = 0 // Spacing between rows
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)

        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: ––––– reloading pipeline replaced (A-4)
    /// Was `reloadCollectionView`; now only mutates the snapshot.
    private func syncAndApplySnapshot(redrawLayout: Bool = false) {
        if redrawLayout {
            collectionView.collectionViewLayout.invalidateLayout()
        }
        applySnapshot(animating: true)
    }

    // Whenever `viewModels` changes from outside → rebuild snapshot
    private func updateUI() {
        showNoSensorsAddedMessage(show: viewModels.isEmpty)
        syncAndApplySnapshot()
    }

    // MARK: ––––– Drag & Drop (A-6)    — only changed performDropWith / reorder
//    func collectionView(_ collectionView: UICollectionView,
//                        performDropWith coordinator: UICollectionViewDropCoordinator) {
//
//        let dest = coordinator.destinationIndexPath ?? IndexPath(item: viewModels.count-1, section: 0)
//        guard coordinator.proposal.operation == .move,
//              let item = coordinator.items.first,
//              let src = item.sourceIndexPath,
//              let model = item.dragItem.localObject as? CardsViewModel else { return }
//
//        // mutate model array
//        viewModels.remove(at: src.item)
//        viewModels.insert(model, at: dest.item)
//
//        // persist order & re-apply snapshot
//        syncAndApplySnapshot()
//
//        coordinator.drop(item.dragItem, toItemAt: dest)
//
//        let macIds = viewModels.compactMap { $0.mac?.value }
//        output.viewDidReorderSensors(with: .manual, orderedIds: macIds)
//    }

    func collectionView(_ collectionView: UICollectionView, performDropWith coordinator: UICollectionViewDropCoordinator) {
        // Get the destination index path
        guard let destinationIndexPath = coordinator.destinationIndexPath else { return }

        // Handle the drop for each item
        for item in coordinator.items {
            if let sourceIndexPath = item.sourceIndexPath {
                // This is a reordering operation within the same collection view

                // Update the data source
                if let itemToMove = dataSource.itemIdentifier(
                    for: sourceIndexPath
                ) {
                    var snapshot = dataSource.snapshot()
                    snapshot.deleteItems([itemToMove])

                    if destinationIndexPath.item >= snapshot
                        .numberOfItems(inSection: .main) {
                        snapshot.appendItems([itemToMove], toSection: .main)
                    } else {
                        let destinationItem = dataSource.itemIdentifier(for: destinationIndexPath)!
                        snapshot.insertItems([itemToMove], beforeItem: destinationItem)
                    }

                    // Apply the snapshot with animation
                    dataSource.apply(snapshot, animatingDifferences: true)

                    // Update our items array to match the new order
                    viewModels = dataSource.snapshot().itemIdentifiers(
                        inSection: .main
                    )

                    // Tell the coordinator we've handled the drop
                    coordinator.drop(item.dragItem, toItemAt: destinationIndexPath)

                    // Clear dragging state in layout
                    if let layout = collectionView.collectionViewLayout as? MasonryLayout {
                        layout.clearDraggingState()
                    }
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, dragSessionDidEnd session: UIDragSession) {
        // Make sure to clear any dragging state
        if let layout = collectionView.collectionViewLayout as? MasonryLayout {
            layout.clearDraggingState()
        }
    }
}

private extension DashboardViewController {
    @objc func handleMenuButtonTap() {
        output.viewDidTriggerMenu()
    }

    private func reloadCollectionView(redrawLayout: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            guard let sSelf = self else { return }
            if redrawLayout {
                sSelf.collectionView.collectionViewLayout.invalidateLayout()
            }
            let oldOffset = sSelf.collectionView.contentOffset
            sSelf.collectionView.reloadWithoutAnimation()
            sSelf.collectionView.setContentOffset(oldOffset, animated: false)
        }
    }

    @objc func handleRefreshValueChanged() {
        // This gets called when refresh control is triggered
        // But we won't make the API call yet - just track that we're in refresh state
        isPulling = true
    }

    @objc func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        if gesture.state == .ended && isPulling {
            // User released their finger and we were in a pulling state
            isPulling = false
            refresher.endRefreshing()
            output.viewDidTriggerPullToRefresh()
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
        if viewModel.canShareTag {
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

      let macIds = viewModels.compactMap { $0.mac?.value }
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

        // Add gesture recognizer to detect when user stops pulling
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(_:)))
        panGesture.delegate = self
        collectionView.addGestureRecognizer(panGesture)
    }

//    func createLayout() -> UICollectionViewLayout {
//        let sectionProvider = { (
//            _: Int,
//            _: NSCollectionLayoutEnvironment
//        ) -> NSCollectionLayoutSection? in
//
//        let widthMultiplier = GlobalHelpers.isDeviceTablet() ?
//            (!GlobalHelpers.isDeviceLandscape() ? 0.5 : 0.3333) :
//            (GlobalHelpers.isDeviceLandscape() ? 0.5 : 1.0)
//
//        let itemSize = NSCollectionLayoutSize(
//            widthDimension: .fractionalWidth(widthMultiplier),
//            heightDimension: .estimated(200)
//        )
//        let item = NSCollectionLayoutItem(layoutSize: itemSize)
//        let itemHorizontalSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 6 : 4
//        item.contentInsets = NSDirectionalEdgeInsets(
//            top: 0,
//            leading: itemHorizontalSpacing,
//            bottom: 0,
//            trailing: itemHorizontalSpacing
//        )
//
//        let groupSize = NSCollectionLayoutSize(
//            widthDimension: .fractionalWidth(1.0),
//            heightDimension: .estimated(1)
//        )
//        let group = NSCollectionLayoutGroup.horizontal(
//            layoutSize: groupSize, subitems: [item]
//        )
//
//        let section = NSCollectionLayoutSection(group: group)
//        section.interGroupSpacing = GlobalHelpers.isDeviceTablet() ? 12 : 8
//        section.contentInsets = NSDirectionalEdgeInsets(
//            top: 0,
//            leading: 0,
//            bottom: 12,
//            trailing: 0
//        )
//        return section
//        }
//
//        let config = UICollectionViewCompositionalLayoutConfiguration()
//        config.scrollDirection = .vertical
//        let layout = UICollectionViewCompositionalLayout(
//            sectionProvider: sectionProvider,
//            configuration: config
//        )
//        return layout
//    }

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

extension DashboardViewController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }
}

//extension DashboardViewController: UICollectionViewDataSource {
//    func collectionView(
//        _: UICollectionView,
//        numberOfItemsInSection _: Int
//    ) -> Int {
//        viewModels.count
//    }
//
//    func collectionView(
//        _ collectionView: UICollectionView,
//        cellForItemAt indexPath: IndexPath
//    ) -> UICollectionViewCell {
//        guard let cell = cell(
//            collectionView: collectionView,
//            indexPath: indexPath,
//            viewModel: viewModels[indexPath.item]
//        )
//        else {
//            fatalError()
//        }
//        return cell
//    }
//}

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

//    func collectionView(
//        _ collectionView: UICollectionView,
//        performDropWith coordinator: UICollectionViewDropCoordinator
//    ) {
//        let destinationIndexPath: IndexPath
//
//        if let indexPath = coordinator.destinationIndexPath {
//            destinationIndexPath = indexPath
//        } else {
//            let row = collectionView.numberOfItems(inSection: 0)
//            destinationIndexPath = IndexPath(row: row, section: 0)
//        }
//
//        guard destinationIndexPath.row < viewModels.count else { return }
//
//        if coordinator.proposal.operation == .move {
//            reorderItems(
//                coordinator,
//                destinationIndexPath: destinationIndexPath,
//                collectionView: collectionView
//            )
//        }
//    }

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

        let macIds = viewModels.compactMap { $0.mac?.value }
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

// MARK: - Masonry Layout Delegate
extension DashboardViewController: MasonryLayoutDelegate {
    func collectionView(_ collectionView: UICollectionView, heightForItemAt indexPath: IndexPath, with width: CGFloat) -> CGFloat {
        // Get the data for this cell
        let viewModel = viewModels[indexPath.item]

        // Calculate the height using the sizing cell
        return calculateHeight(for: viewModel, width: width)
    }

    // Calculate the height by configuring the sizing cell and measuring its height
    private func calculateHeight(for viewModel: CardsViewModel, width: CGFloat) -> CGFloat {
        // Configure the sizing cell with the same data
        sizingCell.frame = CGRect(x: 0, y: 0, width: width, height: 1000) // Height will be determined by autolayout
        sizingCell.configure(with: viewModel, measurementService: measurementService)

        // Layout the cell
        sizingCell.setNeedsLayout()
        sizingCell.layoutIfNeeded()

        // Calculate the height using systemLayoutSizeFitting
        let targetSize = CGSize(width: width, height: UIView.layoutFittingCompressedSize.height)
        let fittingSize = sizingCell.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )

        // Return the calculated height
        return fittingSize.height
    }
}

// MARK: - DashboardViewInput

extension DashboardViewController: DashboardViewInput {

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
        noSensorView.updateView()
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
            from: viewModel.mac?.mac,
            luid: viewModel.luid?.value
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
            alertTextField.text = (defaultName == viewModel.name) ? nil : viewModel.name
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
//    func updateUI() {
//        showNoSensorsAddedMessage(show: viewModels.isEmpty)
//        collectionView.reloadWithoutAnimation()
//    }
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
