// swiftlint:disable file_length

import UIKit

public enum MasonrySection {
    case main
}

// MARK: - Delegate Protocol
public protocol MasonryReorderableLayoutDelegate: AnyObject {
    func collectionView(
        _ collectionView: UICollectionView,
        heightForItemAt indexPath: IndexPath
    ) -> CGFloat

    func numberOfColumns(in collectionView: UICollectionView) -> Int
    func columnSpacing(in collectionView: UICollectionView) -> CGFloat
    func sectionInsets(in collectionView: UICollectionView) -> UIEdgeInsets

    func collectionView(
        _ collectionView: UICollectionView,
        at: IndexPath,
        willMoveTo toIndexPath: IndexPath
    )

    func collectionView(
        _ collectionView: UICollectionView,
        at: IndexPath,
        didMoveTo toIndexPath: IndexPath,
        currentSnapshots: [RuuviTagCardSnapshot]
    )

    func collectionView(
        _ collectionView: UICollectionView,
        allowMoveAt indexPath: IndexPath
    ) -> Bool

    func collectionView(
        _ collectionView: UICollectionView,
        at: IndexPath,
        canMoveTo: IndexPath
    ) -> Bool

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        willBeginDraggingItemAt indexPath: IndexPath
    )

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        didBeginDraggingItemAt indexPath: IndexPath
    )

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        willEndDraggingItemTo indexPath: IndexPath
    )

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        didEndDraggingItemTo indexPath: IndexPath
    )
}

// MARK: - Default Implementations
public extension MasonryReorderableLayoutDelegate {
    func collectionView(
        _ collectionView: UICollectionView,
        at: IndexPath,
        willMoveTo toIndexPath: IndexPath
    ) {}

    func collectionView(
        _ collectionView: UICollectionView,
        at: IndexPath,
        didMoveTo toIndexPath: IndexPath,
        currentSnapshots: [RuuviTagCardSnapshot]
    ) {}

    func collectionView(
        _ collectionView: UICollectionView,
        allowMoveAt indexPath: IndexPath
    ) -> Bool { return true }

    func collectionView(
        _ collectionView: UICollectionView,
        at: IndexPath,
        canMoveTo: IndexPath
    ) -> Bool { return true }

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        willBeginDraggingItemAt indexPath: IndexPath
    ) {}

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        didBeginDraggingItemAt indexPath: IndexPath
    ) {}

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        willEndDraggingItemTo indexPath: IndexPath
    ) {}

    func collectionView(
        _ collectionView: UICollectionView,
        layout: MasonryReorderableLayout,
        didEndDraggingItemTo indexPath: IndexPath
    ) {}
}

// MARK: - Fake Cell View
private class MasonryFakeView: UIView {
    weak var cell: UICollectionViewCell?
    private var cellImageView: UIImageView?
    private var cellHighlightedView: UIImageView?

    var indexPath: IndexPath?
    var originalCenter: CGPoint?
    var cellFrame: CGRect?
    private var originalSize: CGSize?

    init(cell: UICollectionViewCell) {
        super.init(frame: cell.frame)
        self.cell = cell
        self.originalSize = cell.bounds.size
        setupShadow()
        setupImageViews()
        captureImages()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setupShadow() {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0
        layer.shadowRadius = 8.0
        layer.shouldRasterize = true
        layer.rasterizationScale = UIScreen.main.scale
    }

    private func setupImageViews() {
        guard let cell = cell else { return }

        cellImageView = UIImageView(frame: CGRect(origin: .zero,
                                                  size: cell.bounds.size))
        cellImageView?.contentMode = .scaleAspectFill
        cellImageView?.clipsToBounds = true
        cellImageView?.layer.cornerRadius = 8

        cellHighlightedView = UIImageView(frame: CGRect(origin: .zero,
                                                        size: cell.bounds.size))
        cellHighlightedView?.contentMode = .scaleAspectFill
        cellHighlightedView?.clipsToBounds = true
        cellHighlightedView?.layer.cornerRadius = 8

        if let cellImageView = cellImageView,
           let cellHighlightedView = cellHighlightedView {
            addSubview(cellImageView)
            addSubview(cellHighlightedView)
        }
    }

    private func captureImages() {
        guard let cell = cell else { return }

        cell.isHighlighted = true
        cellHighlightedView?.image = getCellImage()
        cell.isHighlighted = false
        cellImageView?.image = getCellImage()
    }

    func pushForwardView() {
        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            options: [.curveEaseOut, .beginFromCurrentState],
            animations: {
                self.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self.layer.shadowOpacity = 0.3
                self.cellHighlightedView?.alpha = 0
            }
        ) { _ in
            self.cellHighlightedView?.removeFromSuperview()
        }
    }

    func pushBackView(_ completion: (() -> Void)?) {
        guard let targetFrame = cellFrame else {
            completion?()
            return
        }

        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.2,
            options: [.allowUserInteraction, .beginFromCurrentState],
            animations: {
                self.transform = .identity
                self.frame = targetFrame
                self.layer.shadowOpacity = 0
                self.cellImageView?.frame = CGRect(origin: .zero,
                                                   size: targetFrame.size)
            }
        ) { _ in
            completion?()
        }
    }

    private func getCellImage() -> UIImage {
        let size = originalSize ?? cell!.bounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            cell!.layer.render(in: context.cgContext)
        }
    }
}

// MARK: - Main Layout Class
// swiftlint:disable:next type_body_length
public class MasonryReorderableLayout: UICollectionViewLayout {

    // MARK: - Public Properties
    public weak var delegate: MasonryReorderableLayoutDelegate?
    public weak var diffableDataSource:
        UICollectionViewDiffableDataSource<MasonrySection, RuuviTagCardSnapshot>?

    // MARK: - Private Properties
    private var isDragging = false
    private var draggedItemIdentifier: RuuviTagCardSnapshot?
    private var lastMoveTime: TimeInterval = 0

    // Gesture recognizers
    private var longPress: UILongPressGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?

    // Drag visual state
    private var cellFakeView: MasonryFakeView?
    private var dragStartCenter: CGPoint?
    private var originalCellSize: CGSize?

    // Layout cache
    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    // Auto-scroll properties
    private var displayLink: CADisplayLink?
    private var continuousScrollDirection: ScrollDirection = .stay
    private var triggerInsets = UIEdgeInsets(top: 100, left: 100,
                                             bottom: 100, right: 100)
    private var triggerPadding = UIEdgeInsets.zero
    private var scrollSpeedValue: CGFloat = 10.0
    private var fakeCellCenter: CGPoint?
    private var panTranslation: CGPoint?

    // Move history tracking to prevent oscillation
    private var recentMoves: [(from: Int, to: Int, time: TimeInterval)] = []
    private let maxRecentMoves = 5
    private let moveConflictWindow: TimeInterval = 0.5
    private let moveThrottleInterval: TimeInterval = 0.15

    // MARK: - Scroll Direction
    private enum ScrollDirection {
        case toTop
        case toEnd
        case stay

        func scrollValue(_ speedValue: CGFloat, percentage: CGFloat) -> CGFloat {
            var value: CGFloat = 0.0
            switch self {
            case .toTop:
                value = -speedValue
            case .toEnd:
                value = speedValue
            case .stay:
                return 0
            }

            let proofedPercentage: CGFloat = max(min(1.0, percentage), 0)
            return value * proofedPercentage
        }
    }

    // MARK: - Computed Properties
    private var offsetFromTop: CGFloat {
        return collectionView!.contentOffset.y
    }

    private var insetsTop: CGFloat {
        return collectionView!.contentInset.top
    }

    private var insetsEnd: CGFloat {
        return collectionView!.contentInset.bottom
    }

    private var collectionViewLength: CGFloat {
        return collectionView!.bounds.height
    }

    private var fakeCellTopEdge: CGFloat? {
        return cellFakeView?.frame.minY
    }

    private var fakeCellEndEdge: CGFloat? {
        return cellFakeView?.frame.maxY
    }

    private var triggerInsetTop: CGFloat {
        return triggerInsets.top
    }

    private var triggerInsetEnd: CGFloat {
        return triggerInsets.bottom
    }

    private var triggerPaddingTop: CGFloat {
        return triggerPadding.top
    }

    private var triggerPaddingEnd: CGFloat {
        return triggerPadding.bottom
    }

    private var safeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return collectionView?.safeAreaInsets ?? UIEdgeInsets.zero
        } else {
            return UIEdgeInsets.zero
        }
    }

    private var adjustedSectionInsets: UIEdgeInsets {
        let originalInsets = sectionInsets
        return UIEdgeInsets(
            top: originalInsets.top + safeAreaInsets.top,
            left: originalInsets.left,
            bottom: originalInsets.bottom + safeAreaInsets.bottom,
            right: originalInsets.right
        )
    }

    private var numberOfColumns: Int {
        delegate?.numberOfColumns(in: collectionView!) ?? 2
    }

    private var columnSpacing: CGFloat {
        delegate?.columnSpacing(in: collectionView!) ?? 12
    }

    private var sectionInsets: UIEdgeInsets {
        delegate?.sectionInsets(in: collectionView!) ??
        UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    }

    private var contentWidth: CGFloat {
        guard let collectionView = collectionView else { return 0 }
        return collectionView.bounds.width -
        collectionView.contentInset.left -
        collectionView.contentInset.right
    }

    private var itemWidth: CGFloat {
        let totalSpacing = columnSpacing * CGFloat(numberOfColumns - 1)
        let availableWidth = contentWidth -
        adjustedSectionInsets.left -
        adjustedSectionInsets.right -
        totalSpacing
        return availableWidth / CGFloat(numberOfColumns)
    }

    // MARK: - Initialization
    public override init() {
        super.init()
        configureObserver()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)
        configureObserver()
    }

    deinit {
        removeObserver(self, forKeyPath: "collectionView")
        invalidateDisplayLink()
    }

    private func configureObserver() {
        addObserver(
            self,
            forKeyPath: "collectionView",
            options: [],
            context: nil
        )
    }

    public override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        if keyPath == "collectionView" {
            setupGestureRecognizers()
        } else {
            super.observeValue(forKeyPath: keyPath, of: object,
                               change: change, context: context)
        }
    }

    // MARK: - Auto-scroll Configuration
    public func configureAutoScroll(
        triggerInsets: UIEdgeInsets = UIEdgeInsets(top: 100, left: 100,
                                                   bottom: 100, right: 100),
        triggerPadding: UIEdgeInsets = .zero,
        scrollSpeed: CGFloat = 10.0
    ) {
        self.triggerInsets = triggerInsets
        self.triggerPadding = triggerPadding
        self.scrollSpeedValue = scrollSpeed
    }

    // MARK: - Display Link Management
    private func setUpDisplayLink() {
        guard displayLink == nil else { return }

        displayLink = CADisplayLink(target: self,
                                    selector: #selector(continuousScroll))
        displayLink!.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
    }

    private func invalidateDisplayLink() {
        continuousScrollDirection = .stay
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Data Source Integration
    public func setDataSource(
        _ dataSource: UICollectionViewDiffableDataSource<MasonrySection, RuuviTagCardSnapshot>
    ) {
        self.diffableDataSource = dataSource
    }

    private func getCurrentItems() -> [RuuviTagCardSnapshot] {
        guard let dataSource = diffableDataSource else { return [] }
        let snapshot = dataSource.snapshot()
        return snapshot.itemIdentifiers(inSection: .main)
    }

    // MARK: - Layout Core
    public override var collectionViewContentSize: CGSize {
        CGSize(width: contentWidth, height: contentHeight)
    }

    public override func prepare() {
        super.prepare()
        guard let collectionView = collectionView else { return }

        layoutAttributes.removeAll()

        var columnHeights = Array(repeating: adjustedSectionInsets.top,
                                  count: numberOfColumns)
        var columnXOffsets: [CGFloat] = []

        for column in 0..<numberOfColumns {
            let xOffset = adjustedSectionInsets.left +
            CGFloat(column) * (itemWidth + columnSpacing)
            columnXOffsets.append(xOffset)
        }

        guard let itemCount = diffableDataSource?.snapshot().numberOfItems(
            inSection: .main
        ), itemCount > 0 else { return }

        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)

            let isDraggedItem = isDragging &&
            draggedItemIdentifier != nil &&
            isItemAtIndexPathDragged(indexPath)

            let height: CGFloat
            if isDraggedItem {
                height = originalCellSize?.height ?? 100
            } else {
                height = delegate?.collectionView(collectionView,
                                                  heightForItemAt: indexPath) ?? 100
            }

            let targetColumn = shortestColumnIndex(columnHeights)

            let frame = CGRect(
                x: columnXOffsets[targetColumn],
                y: columnHeights[targetColumn],
                width: itemWidth,
                height: height
            )

            let attributes = UICollectionViewLayoutAttributes(
                forCellWith: indexPath
            )
            attributes.frame = frame

            if isDraggedItem {
                attributes.alpha = 0.0
            }

            layoutAttributes.append(attributes)
            columnHeights[targetColumn] = frame.maxY + columnSpacing
        }

        contentHeight = (columnHeights.max() ?? 0) + adjustedSectionInsets.bottom
    }

    // MARK: - Auto-scroll Logic
    private func beginScrollIfNeeded() {
        guard cellFakeView != nil,
              let fakeCellTopEdge = fakeCellTopEdge,
              let fakeCellEndEdge = fakeCellEndEdge else { return }

        if fakeCellTopEdge <= offsetFromTop + triggerPaddingTop +
            triggerInsetTop {
            continuousScrollDirection = .toTop
            setUpDisplayLink()
        } else if fakeCellEndEdge >= offsetFromTop + collectionViewLength -
                    triggerPaddingEnd - triggerInsetEnd {
            continuousScrollDirection = .toEnd
            setUpDisplayLink()
        } else {
            invalidateDisplayLink()
        }
    }

    @objc private func continuousScroll() {
        guard let fakeCell = cellFakeView else { return }

        let percentage = calcTriggerPercentage()
        var scrollRate = continuousScrollDirection.scrollValue(
            self.scrollSpeedValue,
            percentage: percentage
        )

        let offset = offsetFromTop
        let length = collectionViewLength

        if contentHeight + insetsTop + insetsEnd <= length {
            return
        }

        if offset + scrollRate <= -insetsTop {
            scrollRate = -insetsTop - offset
        } else if offset + scrollRate >= contentHeight + insetsEnd - length {
            scrollRate = contentHeight + insetsEnd - length - offset
        }

        collectionView!.performBatchUpdates({
            self.fakeCellCenter?.y += scrollRate
            fakeCell.center.y = self.fakeCellCenter!.y +
            (self.panTranslation?.y ?? 0)
            self.collectionView?.contentOffset.y += scrollRate
        }, completion: nil)

        handleRealtimeReordering()
    }

    private func calcTriggerPercentage() -> CGFloat {
        guard cellFakeView != nil else { return 0 }

        let offset = offsetFromTop
        let offsetEnd = offsetFromTop + collectionViewLength
        let paddingEnd = triggerPaddingEnd

        var percentage: CGFloat = 0

        if self.continuousScrollDirection == .toTop {
            if let fakeCellEdge = fakeCellTopEdge {
                percentage = 1.0 - ((fakeCellEdge -
                                     (offset + triggerPaddingTop)) /
                                    triggerInsetTop)
            }
        } else if continuousScrollDirection == .toEnd {
            if let fakeCellEdge = fakeCellEndEdge {
                percentage = 1.0 - (((insetsTop + offsetEnd - paddingEnd) -
                                     (fakeCellEdge + insetsTop)) /
                                    triggerInsetEnd)
            }
        }

        percentage = min(1.0, percentage)
        percentage = max(0, percentage)
        return percentage
    }

    // MARK: - Gesture Handlers
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        var indexPath: IndexPath? = collectionView?.indexPathForItem(at: location)

        if let cellFakeView = cellFakeView {
            indexPath = cellFakeView.indexPath
        }

        guard let indexPath = indexPath else { return }

        switch gesture.state {
        case .began:
            beginDrag(at: indexPath)
        case .cancelled, .ended:
            endDrag(indexPath)
        default:
            break
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let cellFakeView = cellFakeView,
              let fakeCellCenter = fakeCellCenter else { return }

        panTranslation = gesture.translation(in: collectionView!)

        switch gesture.state {
        case .changed:
            if let panTranslation = panTranslation {
                cellFakeView.center.x = fakeCellCenter.x + panTranslation.x
                cellFakeView.center.y = fakeCellCenter.y + panTranslation.y

                beginScrollIfNeeded()
                handleRealtimeReordering()
            }

        case .cancelled, .ended:
            invalidateDisplayLink()

        default:
            break
        }
    }

    // MARK: - Drag Management
    private func beginDrag(at indexPath: IndexPath) {
        guard delegate?.collectionView(collectionView!,
                                       allowMoveAt: indexPath) != false else {
            return
        }

        guard let dataSource = diffableDataSource,
              let item = dataSource.itemIdentifier(for: indexPath) else {
            return
        }

        isDragging = true
        draggedItemIdentifier = item

        delegate?.collectionView(collectionView!, layout: self,
                                 willBeginDraggingItemAt: indexPath)

        collectionView?.scrollsToTop = false

        guard let currentCell = collectionView?.cellForItem(at: indexPath) else {
            return
        }

        originalCellSize = currentCell.bounds.size

        cellFakeView = MasonryFakeView(cell: currentCell)
        cellFakeView!.indexPath = indexPath
        cellFakeView!.originalCenter = currentCell.center
        cellFakeView!.cellFrame = layoutAttributesForItem(at: indexPath)!.frame
        collectionView?.addSubview(cellFakeView!)

        dragStartCenter = cellFakeView!.center
        fakeCellCenter = cellFakeView!.center

        invalidateLayout()
        cellFakeView?.pushForwardView()

        delegate?.collectionView(collectionView!, layout: self,
                                 didBeginDraggingItemAt: indexPath)
    }

    private func endDrag(_ indexPath: IndexPath?) {
        guard let cellFakeView = cellFakeView else { return }

        let finalIndexPath = cellFakeView.indexPath ??
        IndexPath(item: 0, section: 0)

        delegate?.collectionView(collectionView!, layout: self,
                                 willEndDraggingItemTo: finalIndexPath)

        collectionView?.scrollsToTop = true

        invalidateDisplayLink()

        let finalTargetFrame = calculateFreshTargetFrame(for: finalIndexPath)
        cellFakeView.cellFrame = finalTargetFrame

        fakeCellCenter = nil
        panTranslation = nil

        cellFakeView.pushBackView { [weak self] in
            self?.cleanupDragState()
            cellFakeView.removeFromSuperview()
            self?.cellFakeView = nil

            self?.invalidateLayout()
            self?.delegate?.collectionView(
                self!.collectionView!,
                layout: self!,
                didEndDraggingItemTo: finalIndexPath
            )
        }
    }

    private func cleanupDragState() {
        isDragging = false
        draggedItemIdentifier = nil
        dragStartCenter = nil
        originalCellSize = nil
        lastMoveTime = 0
        recentMoves.removeAll()
    }

    // MARK: - Reordering Logic
    private func handleRealtimeReordering() {
        guard let fakeCell = cellFakeView,
              let draggedItem = draggedItemIdentifier,
              let dataSource = diffableDataSource else { return }

        let currentTime = CACurrentMediaTime()
        if currentTime - lastMoveTime < moveThrottleInterval {
            return
        }

        guard let currentIndexPath = dataSource.indexPath(for: draggedItem) else {
            return
        }

        let targetIndexPath = findTargetIndexPathWithHysteresis(
            for: fakeCell.center,
            currentIndex: currentIndexPath.item
        )
        guard let targetIndexPath = targetIndexPath else { return }

        guard currentIndexPath != targetIndexPath else { return }

        let distance = abs(currentIndexPath.item - targetIndexPath.item)
        if distance == 0 { return }

        if hasRecentMoveConflict(from: currentIndexPath.item,
                                 to: targetIndexPath.item) {
            return
        }

        lastMoveTime = currentTime
        recordMove(from: currentIndexPath.item, to: targetIndexPath.item)

        if delegate?.collectionView(collectionView!, at: currentIndexPath,
                                    canMoveTo: targetIndexPath) == false {
            return
        }

        performDataSourceReorder(from: currentIndexPath, to: targetIndexPath)
    }

    private func recordMove(from: Int, to: Int) {
        let currentTime = CACurrentMediaTime()
        recentMoves.append((from: from, to: to, time: currentTime))

        recentMoves = recentMoves.filter {
            currentTime - $0.time < moveConflictWindow
        }

        if recentMoves.count > maxRecentMoves {
            recentMoves.removeFirst()
        }
    }

    private func hasRecentMoveConflict(from: Int, to: Int) -> Bool {
        let currentTime = CACurrentMediaTime()

        return recentMoves.contains { move in
            currentTime - move.time < moveConflictWindow &&
            move.from == to && move.to == from
        }
    }

    private func findTargetIndexPathWithHysteresis(
        for point: CGPoint,
        currentIndex: Int
    ) -> IndexPath? {
        var candidates: [(IndexPath, CGFloat, CGRect)] = []

        for attributes in layoutAttributes {
            if attributes.alpha > 0 {
                let frame = attributes.frame
                let center = attributes.center

                let distance = sqrt(pow(center.x - point.x, 2) +
                                    pow(center.y - point.y, 2))

                candidates.append((attributes.indexPath, distance, frame))
            }
        }

        candidates.sort { $0.1 < $1.1 }

        if let currentCandidate = candidates.first(where: {
            $0.0.item == currentIndex
        }) {
            let currentDistance = currentCandidate.1

            if let closest = candidates.first,
               closest.0.item != currentIndex {
                let hysteresisThreshold: CGFloat = 30.0

                if currentDistance < closest.1 + hysteresisThreshold {
                    return IndexPath(item: currentIndex, section: 0)
                }
            }
        }

        if let closest = candidates.first {
            let targetFrame = closest.2

            let intersection = targetFrame.intersection(CGRect(
                x: point.x - 20, y: point.y - 20,
                width: 40, height: 40
            ))

            if intersection.width > 10 && intersection.height > 10 {
                return closest.0
            }
        }

        return nil
    }

    private func performDataSourceReorder(
        from fromIndexPath: IndexPath,
        to toIndexPath: IndexPath
    ) {
        guard let dataSource = diffableDataSource else { return }

        let currentSnapshot = dataSource.snapshot()
        var items = currentSnapshot.itemIdentifiers(inSection: .main)

        guard fromIndexPath.item < items.count &&
                toIndexPath.item < items.count &&
                fromIndexPath.item >= 0 &&
                toIndexPath.item >= 0 else {
            return
        }

        guard fromIndexPath.item != toIndexPath.item else { return }

        let movedItem = items.remove(at: fromIndexPath.item)
        items.insert(movedItem, at: toIndexPath.item)

        var newSnapshot = NSDiffableDataSourceSnapshot<MasonrySection,
                                                       RuuviTagCardSnapshot>()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(items, toSection: .main)

        delegate?.collectionView(collectionView!, at: fromIndexPath,
                                 willMoveTo: toIndexPath)

        dataSource.apply(newSnapshot, animatingDifferences: true) { [weak self] in
            DispatchQueue.main.async {
                self?.updateFakeCellFrameAfterReorder(
                    targetIndexPath: toIndexPath
                )
                self?.delegate?.collectionView(
                    self!.collectionView!,
                    at: fromIndexPath,
                    didMoveTo: toIndexPath,
                    currentSnapshots: newSnapshot.itemIdentifiers(inSection: .main)
                )
            }
        }
    }

    // MARK: - Frame Calculations
    private func calculateFreshTargetFrame(for indexPath: IndexPath) -> CGRect {
        guard let collectionView = collectionView else { return CGRect.zero }

        var columnHeights = Array(repeating: adjustedSectionInsets.top,
                                  count: numberOfColumns)
        var columnXOffsets: [CGFloat] = []

        for column in 0..<numberOfColumns {
            let xOffset = adjustedSectionInsets.left +
            CGFloat(column) * (itemWidth + columnSpacing)
            columnXOffsets.append(xOffset)
        }

        let itemCount = collectionView.numberOfItems(inSection: 0)

        for item in 0..<itemCount {
            let currentIndexPath = IndexPath(item: item, section: 0)

            let height: CGFloat
            if currentIndexPath == indexPath {
                height = originalCellSize?.height ?? 100
            } else {
                height = delegate?.collectionView(collectionView,
                                                  heightForItemAt: currentIndexPath) ?? 100
            }

            let targetColumn = shortestColumnIndex(columnHeights)

            let frame = CGRect(
                x: columnXOffsets[targetColumn],
                y: columnHeights[targetColumn],
                width: itemWidth,
                height: height
            )

            if currentIndexPath == indexPath {
                return frame
            }

            columnHeights[targetColumn] = frame.maxY + columnSpacing
        }

        return CGRect.zero
    }

    private func updateFakeCellFrameAfterReorder(targetIndexPath: IndexPath) {
        guard let fakeCell = cellFakeView else { return }

        invalidateLayout()

        let targetFrame = calculateFreshTargetFrame(for: targetIndexPath)

        fakeCell.cellFrame = targetFrame
        fakeCell.indexPath = targetIndexPath
    }

    // MARK: - Helper Methods
    private func isItemAtIndexPathDragged(_ indexPath: IndexPath) -> Bool {
        guard let draggedItem = draggedItemIdentifier,
              let dataSource = diffableDataSource else { return false }

        let currentIndexPath = dataSource.indexPath(for: draggedItem)
        return currentIndexPath == indexPath
    }

    public override func layoutAttributesForElements(
        in rect: CGRect
    ) -> [UICollectionViewLayoutAttributes]? {
        return layoutAttributes.filter { $0.frame.intersects(rect) }
    }

    public override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> UICollectionViewLayoutAttributes? {
        return layoutAttributes.first { $0.indexPath == indexPath }
    }

    public override func shouldInvalidateLayout(
        forBoundsChange newBounds: CGRect
    ) -> Bool {
        guard let collectionView = collectionView else { return false }
        return !newBounds.size.equalTo(collectionView.bounds.size)
    }

    private func setupGestureRecognizers() {
        guard let collectionView = collectionView else { return }
        guard longPress == nil && panGesture == nil else { return }

        longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        panGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePanGesture(_:))
        )

        longPress?.delegate = self
        panGesture?.delegate = self
        panGesture?.maximumNumberOfTouches = 1

        if let gestures = collectionView.gestureRecognizers {
            for gestureRecognizer in gestures {
                if gestureRecognizer is UILongPressGestureRecognizer {
                    gestureRecognizer.require(toFail: self.longPress!)
                }
            }
        }

        collectionView.addGestureRecognizer(longPress!)
        collectionView.addGestureRecognizer(panGesture!)
    }

    public func cancelDrag() {
        endDrag(nil)
    }

    private func shortestColumnIndex(_ columnHeights: [CGFloat]) -> Int {
        return columnHeights.enumerated().min(by: {
            $0.element < $1.element
        })?.offset ?? 0
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MasonryReorderableLayout: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(
        _ gestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let location = gestureRecognizer.location(in: collectionView)
        if let indexPath = collectionView?.indexPathForItem(at: location),
           delegate?.collectionView(collectionView!,
                                    allowMoveAt: indexPath) == false {
            return false
        }

        if gestureRecognizer == longPress {
            return !(collectionView!.panGestureRecognizer.state != .possible &&
                     collectionView!.panGestureRecognizer.state != .failed)
        } else if gestureRecognizer == panGesture {
            return !(longPress!.state == .possible ||
                     longPress!.state == .failed)
        }

        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
        UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer == panGesture {
            return otherGestureRecognizer == longPress
        } else if gestureRecognizer == collectionView?.panGestureRecognizer {
            return longPress!.state != .possible ||
            longPress!.state != .failed
        }

        return true
    }
}

// swiftlint:enable file_length
