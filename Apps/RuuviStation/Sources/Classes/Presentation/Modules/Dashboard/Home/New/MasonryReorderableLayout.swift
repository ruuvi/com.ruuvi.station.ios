// swiftlint:disable file_length
// The implementation of this class is inspired by the implementation of
// https://github.com/ra1028/RAReorderableLayout at the base, modified and
// enriched for the usage of MasonryLayout for RuuviTag.

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

// MARK: - Preview Cell View
private class MasonryDragPreviewView: UIView {
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

        cellImageView = UIImageView(frame: CGRect(origin: .zero, size: cell.bounds.size))
        cellImageView?.contentMode = .scaleAspectFill
        cellImageView?.clipsToBounds = true
        cellImageView?.layer.cornerRadius = 8

        cellHighlightedView = UIImageView(frame: CGRect(origin: .zero, size: cell.bounds.size))
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
            animations: { [weak self] in
                self?.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                self?.layer.shadowOpacity = 0.3
                self?.cellHighlightedView?.alpha = 0
            }
        ) { [weak self] _ in
            self?.cellHighlightedView?.removeFromSuperview()
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
            animations: { [weak self] in
                self?.transform = .identity
                self?.frame = targetFrame
                self?.layer.shadowOpacity = 0
                self?.cellImageView?.frame = CGRect(origin: .zero, size: targetFrame.size)
            }
        ) { _ in
            completion?()
        }
    }

    private func getCellImage() -> UIImage {
        guard let cell = cell else { return UIImage() }
        let size = originalSize ?? cell.bounds.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            cell.layer.render(in: context.cgContext)
        }
    }
}

// MARK: - Layout Configuration
private struct LayoutConfiguration {
    let numberOfColumns: Int
    let columnSpacing: CGFloat
    let sectionInsets: UIEdgeInsets
    let itemWidth: CGFloat
    let columnXOffsets: [CGFloat]

    init(collectionView: UICollectionView, delegate: MasonryReorderableLayoutDelegate?) {
        numberOfColumns = delegate?.numberOfColumns(in: collectionView) ?? 2
        columnSpacing = delegate?.columnSpacing(in: collectionView) ?? 12
        sectionInsets = delegate?.sectionInsets(in: collectionView) ??
            UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let safeAreaInsets: UIEdgeInsets
        if #available(iOS 11.0, *) {
            safeAreaInsets = collectionView.safeAreaInsets
        } else {
            safeAreaInsets = UIEdgeInsets.zero
        }

        let adjustedSectionInsets = UIEdgeInsets(
            top: sectionInsets.top + safeAreaInsets.top,
            left: sectionInsets.left,
            bottom: sectionInsets.bottom + safeAreaInsets.bottom,
            right: sectionInsets.right
        )

        let contentWidth = collectionView.bounds.width -
            collectionView.contentInset.left -
            collectionView.contentInset.right

        let totalSpacing = columnSpacing * CGFloat(numberOfColumns - 1)
        let availableWidth = contentWidth - adjustedSectionInsets.left -
            adjustedSectionInsets.right - totalSpacing

        itemWidth = availableWidth / CGFloat(numberOfColumns)

        var offsets: [CGFloat] = []
        for column in 0..<numberOfColumns {
            let xOffset = adjustedSectionInsets.left + CGFloat(column) * (itemWidth + columnSpacing)
            offsets.append(xOffset)
        }
        columnXOffsets = offsets
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
    private var collectionViewObservation: NSKeyValueObservation?
    private var longPress: UILongPressGestureRecognizer?
    private var panGesture: UIPanGestureRecognizer?

    // Drag visual state
    private var cellPreviewView: MasonryDragPreviewView?
    private var dragStartCenter: CGPoint?
    private var originalCellSize: CGSize?

    // Layout cache
    private var layoutAttributes: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0
    private var cachedConfiguration: LayoutConfiguration?

    // Auto-scroll properties
    private var displayLink: CADisplayLink?
    private var continuousScrollDirection: ScrollDirection = .stay
    private var triggerInsets = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100)
    private var triggerPadding = UIEdgeInsets.zero
    private var scrollSpeedValue: CGFloat = 10.0
    private var previewCellCenter: CGPoint?
    private var panTranslation: CGPoint?

    // Move history tracking to prevent oscillation
    private var recentMoves: [
        // swiftlint:disable large_tuple
        (from: Int, to: Int, time: TimeInterval)
        // swiftlint:enable large_tuple
    ] = []
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
    private var safeCollectionView: UICollectionView? {
        return collectionView
    }

    private func getLayoutConfiguration() -> LayoutConfiguration? {
        guard let collectionView = safeCollectionView else { return nil }

        if let cached = cachedConfiguration {
            return cached
        }

        let config = LayoutConfiguration(collectionView: collectionView, delegate: delegate)
        cachedConfiguration = config
        return config
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
        cleanupResources()
    }

    private func cleanupResources() {
        collectionViewObservation?.invalidate()
        invalidateDisplayLink()
        removeGestureRecognizers()
    }

    private func configureObserver() {
        collectionViewObservation = observe(
            \.collectionView,
             options: [.new, .initial]
        ) { [weak self] _, _ in
            self?.setupGestureRecognizers()
        }
    }

    // MARK: - Auto-scroll Configuration
    public func configureAutoScroll(
        triggerInsets: UIEdgeInsets = UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
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

        displayLink = CADisplayLink(target: self, selector: #selector(continuousScroll))
        displayLink?.add(to: RunLoop.main, forMode: RunLoop.Mode.common)
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
        guard getLayoutConfiguration() != nil else { return .zero }
        let contentWidth = safeCollectionView?.bounds.width ?? 0
        return CGSize(width: contentWidth, height: contentHeight)
    }

    public override func prepare() {
        super.prepare()
        guard let collectionView = safeCollectionView,
              let config = getLayoutConfiguration(),
              let dataSource = diffableDataSource else { return }

        layoutAttributes.removeAll()

        var columnHeights = Array(repeating: config.sectionInsets.top, count: config.numberOfColumns)
        let snapshot = dataSource.snapshot()
        let itemCount = snapshot.numberOfItems(inSection: .main)

        guard itemCount > 0 else {
            contentHeight = config.sectionInsets.top + config.sectionInsets.bottom
            return
        }

        for item in 0..<itemCount {
            let indexPath = IndexPath(item: item, section: 0)
            let attributes = createLayoutAttributes(
                for: indexPath,
                config: config,
                columnHeights: &columnHeights,
                collectionView: collectionView
            )
            layoutAttributes.append(attributes)
        }

        contentHeight = (columnHeights.max() ?? 0) + config.sectionInsets.bottom
    }

    private func createLayoutAttributes(
        for indexPath: IndexPath,
        config: LayoutConfiguration,
        columnHeights: inout [CGFloat],
        collectionView: UICollectionView
    ) -> UICollectionViewLayoutAttributes {

        let isDraggedItem = isDragging &&
            draggedItemIdentifier != nil &&
            isItemAtIndexPathDragged(indexPath)

        let height: CGFloat
        if isDraggedItem {
            height = originalCellSize?.height ?? 100
        } else {
            height = delegate?.collectionView(collectionView, heightForItemAt: indexPath) ?? 100
        }

        let targetColumn = shortestColumnIndex(columnHeights)
        let frame = CGRect(
            x: config.columnXOffsets[targetColumn],
            y: columnHeights[targetColumn],
            width: config.itemWidth,
            height: height
        )

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frame

        if isDraggedItem {
            attributes.alpha = 0.0
        }

        columnHeights[targetColumn] = frame.maxY + config.columnSpacing
        return attributes
    }

    // MARK: - Auto-scroll Logic
    private func beginScrollIfNeeded() {
        guard let collectionView = safeCollectionView,
              cellPreviewView != nil,
              let previewCellTopEdge = cellPreviewView?.frame.minY,
              let previewCellEndEdge = cellPreviewView?.frame.maxY else { return }

        let offsetFromTop = collectionView.contentOffset.y
        let collectionViewLength = collectionView.bounds.height

        if previewCellTopEdge <= offsetFromTop + triggerPadding.top + triggerInsets.top {
            continuousScrollDirection = .toTop
            setUpDisplayLink()
        } else if previewCellEndEdge >= offsetFromTop + collectionViewLength -
                    triggerPadding.bottom - triggerInsets.bottom {
            continuousScrollDirection = .toEnd
            setUpDisplayLink()
        } else {
            invalidateDisplayLink()
        }
    }

    @objc private func continuousScroll() {
        guard let collectionView = safeCollectionView,
              let previewCell = cellPreviewView else { return }

        let percentage = calcTriggerPercentage()
        var scrollRate = continuousScrollDirection.scrollValue(scrollSpeedValue, percentage: percentage)

        let offset = collectionView.contentOffset.y
        let length = collectionView.bounds.height
        let insetsTop = collectionView.contentInset.top
        let insetsEnd = collectionView.contentInset.bottom

        if contentHeight + insetsTop + insetsEnd <= length {
            return
        }

        if offset + scrollRate <= -insetsTop {
            scrollRate = -insetsTop - offset
        } else if offset + scrollRate >= contentHeight + insetsEnd - length {
            scrollRate = contentHeight + insetsEnd - length - offset
        }

        collectionView.performBatchUpdates({ [weak self] in
            self?.previewCellCenter?.y += scrollRate
            if let previewCellCenter = self?.previewCellCenter,
               let panTranslation = self?.panTranslation {
                previewCell.center.y = previewCellCenter.y + panTranslation.y
            }
            collectionView.contentOffset.y += scrollRate
        }, completion: nil)

        handleRealtimeReordering()
    }

    private func calcTriggerPercentage() -> CGFloat {
        guard let collectionView = safeCollectionView,
              let previewCell = cellPreviewView else { return 0 }

        let offset = collectionView.contentOffset.y
        let offsetEnd = offset + collectionView.bounds.height
        let insetsTop = collectionView.contentInset.top

        var percentage: CGFloat = 0

        if continuousScrollDirection == .toTop {
            let previewCellEdge = previewCell.frame.minY
            percentage = 1.0 - ((previewCellEdge - (offset + triggerPadding.top)) / triggerInsets.top)
        } else if continuousScrollDirection == .toEnd {
            let previewCellEdge = previewCell.frame.maxY
            percentage = 1.0 - (((insetsTop + offsetEnd - triggerPadding.bottom) -
                                 (previewCellEdge + insetsTop)) / triggerInsets.bottom)
        }

        return max(0, min(1.0, percentage))
    }

    // MARK: - Gesture Handlers
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard let collectionView = safeCollectionView else { return }

        let location = gesture.location(in: collectionView)
        var indexPath: IndexPath? = collectionView.indexPathForItem(at: location)

        if let previewView = cellPreviewView {
            indexPath = previewView.indexPath
        }

        guard let validIndexPath = indexPath else { return }

        switch gesture.state {
        case .began:
            beginDrag(at: validIndexPath)
        case .cancelled, .ended:
            endDrag(validIndexPath)
        default:
            break
        }
    }

    @objc private func handlePanGesture(_ gesture: UIPanGestureRecognizer) {
        guard let collectionView = safeCollectionView,
              let previewView = cellPreviewView,
              let centerPoint = previewCellCenter else { return }

        panTranslation = gesture.translation(in: collectionView)

        switch gesture.state {
        case .changed:
            if let translation = panTranslation {
                previewView.center.x = centerPoint.x + translation.x
                previewView.center.y = centerPoint.y + translation.y

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
        guard let collectionView = safeCollectionView else { return }

        guard delegate?.collectionView(collectionView, allowMoveAt: indexPath) != false else {
            return
        }

        guard let dataSource = diffableDataSource,
              let item = dataSource.itemIdentifier(for: indexPath),
              let currentCell = collectionView.cellForItem(at: indexPath) else {
            return
        }

        isDragging = true
        draggedItemIdentifier = item

        delegate?.collectionView(collectionView, layout: self, willBeginDraggingItemAt: indexPath)
        collectionView.scrollsToTop = false

        originalCellSize = currentCell.bounds.size
        cellPreviewView = MasonryDragPreviewView(cell: currentCell)

        if let previewView = cellPreviewView,
           let cellFrame = layoutAttributesForItem(at: indexPath)?.frame {
            previewView.indexPath = indexPath
            previewView.originalCenter = currentCell.center
            previewView.cellFrame = cellFrame
            collectionView.addSubview(previewView)
            dragStartCenter = previewView.center
            previewCellCenter = previewView.center
        }

        invalidateLayout()
        cellPreviewView?.pushForwardView()

        delegate?.collectionView(collectionView, layout: self, didBeginDraggingItemAt: indexPath)
    }

    private func endDrag(_ indexPath: IndexPath?) {
        guard let collectionView = safeCollectionView,
              let previewView = cellPreviewView else { return }

        let finalIndexPath = previewView.indexPath ?? IndexPath(item: 0, section: 0)

        delegate?.collectionView(collectionView, layout: self, willEndDraggingItemTo: finalIndexPath)

        collectionView.scrollsToTop = true
        invalidateDisplayLink()

        let finalTargetFrame = calculateFreshTargetFrame(for: finalIndexPath)
        previewView.cellFrame = finalTargetFrame

        previewCellCenter = nil
        panTranslation = nil

        previewView.pushBackView { [weak self] in
            self?.cleanupDragState()
            previewView.removeFromSuperview()
            self?.cellPreviewView = nil
            self?.invalidateLayout()
            self?.delegate?.collectionView(
                collectionView,
                layout: self ?? MasonryReorderableLayout(),
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
        cachedConfiguration = nil // Force recalculation
    }

    // MARK: - Reordering Logic
    private func handleRealtimeReordering() {
        guard let collectionView = safeCollectionView,
              let previewCell = cellPreviewView,
              let draggedItem = draggedItemIdentifier,
              let dataSource = diffableDataSource else { return }

        let currentTime = CACurrentMediaTime()
        if currentTime - lastMoveTime < moveThrottleInterval {
            return
        }

        guard let currentIndexPath = dataSource.indexPath(for: draggedItem) else { return }

        guard let targetIndexPath = findTargetIndexPathWithHysteresis(
            for: previewCell.center,
            currentIndex: currentIndexPath.item
        ) else { return }

        guard currentIndexPath != targetIndexPath else { return }

        let distance = abs(currentIndexPath.item - targetIndexPath.item)
        guard distance > 0 else { return }

        guard !hasRecentMoveConflict(from: currentIndexPath.item, to: targetIndexPath.item) else {
            return
        }

        lastMoveTime = currentTime
        recordMove(from: currentIndexPath.item, to: targetIndexPath.item)

        guard delegate?.collectionView(collectionView, at: currentIndexPath, canMoveTo: targetIndexPath) != false else {
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
        // swiftlint:disable:next large_tuple
        var candidates: [(IndexPath, CGFloat, CGRect)] = []

        for attributes in layoutAttributes where attributes.alpha > 0 {
            let frame = attributes.frame
            let center = attributes.center

            let distance = sqrt(pow(center.x - point.x, 2) + pow(center.y - point.y, 2))
            candidates.append((attributes.indexPath, distance, frame))
        }

        candidates.sort { $0.1 < $1.1 }

        if let currentCandidate = candidates.first(where: { $0.0.item == currentIndex }) {
            let currentDistance = currentCandidate.1

            if let closest = candidates.first, closest.0.item != currentIndex {
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

    private func performDataSourceReorder(from fromIndexPath: IndexPath, to toIndexPath: IndexPath) {
        guard let collectionView = safeCollectionView,
              let dataSource = diffableDataSource else { return }

        let currentSnapshot = dataSource.snapshot()
        var items = currentSnapshot.itemIdentifiers(inSection: .main)

        guard fromIndexPath.item < items.count &&
                toIndexPath.item < items.count &&
                fromIndexPath.item >= 0 &&
                toIndexPath.item >= 0 &&
                fromIndexPath.item != toIndexPath.item else { return }

        let movedItem = items.remove(at: fromIndexPath.item)
        items.insert(movedItem, at: toIndexPath.item)

        var newSnapshot = NSDiffableDataSourceSnapshot<MasonrySection, RuuviTagCardSnapshot>()
        newSnapshot.appendSections([.main])
        newSnapshot.appendItems(items, toSection: .main)

        delegate?.collectionView(collectionView, at: fromIndexPath, willMoveTo: toIndexPath)

        dataSource.apply(newSnapshot, animatingDifferences: true) { [weak self] in
            DispatchQueue.main.async {
                self?.updatePreviewCellFrameAfterReorder(targetIndexPath: toIndexPath)
                self?.delegate?.collectionView(
                    collectionView,
                    at: fromIndexPath,
                    didMoveTo: toIndexPath,
                    currentSnapshots: newSnapshot.itemIdentifiers(inSection: .main)
                )
            }
        }
    }

    // MARK: - Frame Calculations
    private func calculateFreshTargetFrame(for indexPath: IndexPath) -> CGRect {
        guard let collectionView = safeCollectionView,
              let config = getLayoutConfiguration() else { return CGRect.zero }

        var columnHeights = Array(repeating: config.sectionInsets.top, count: config.numberOfColumns)
        let itemCount = collectionView.numberOfItems(inSection: 0)

        for item in 0..<itemCount {
            let currentIndexPath = IndexPath(item: item, section: 0)

            let height: CGFloat
            if currentIndexPath == indexPath {
                height = originalCellSize?.height ?? 100
            } else {
                height = delegate?.collectionView(collectionView, heightForItemAt: currentIndexPath) ?? 100
            }

            let targetColumn = shortestColumnIndex(columnHeights)
            let frame = CGRect(
                x: config.columnXOffsets[targetColumn],
                y: columnHeights[targetColumn],
                width: config.itemWidth,
                height: height
            )

            if currentIndexPath == indexPath {
                return frame
            }

            columnHeights[targetColumn] = frame.maxY + config.columnSpacing
        }

        return CGRect.zero
    }

    private func updatePreviewCellFrameAfterReorder(targetIndexPath: IndexPath) {
        guard let previewCell = cellPreviewView else { return }

        invalidateLayout()

        let targetFrame = calculateFreshTargetFrame(for: targetIndexPath)
        previewCell.cellFrame = targetFrame
        previewCell.indexPath = targetIndexPath
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

    public override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = safeCollectionView else { return false }
        let shouldInvalidate = !newBounds.size.equalTo(collectionView.bounds.size)
        if shouldInvalidate {
            cachedConfiguration = nil // Clear cache when bounds change
        }
        return shouldInvalidate
    }

    private func setupGestureRecognizers() {
        guard let collectionView = safeCollectionView else { return }
        guard longPress == nil && panGesture == nil else { return }

        removeGestureRecognizers() // Ensure clean state

        longPress = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleLongPress(_:))
        )
        panGesture = UIPanGestureRecognizer(
            target: self,
            action: #selector(handlePanGesture(_:))
        )

        guard let longPress = longPress, let panGesture = panGesture else { return }

        longPress.delegate = self
        panGesture.delegate = self
        panGesture.maximumNumberOfTouches = 1

        // Configure gesture priority
        if let existingGestures = collectionView.gestureRecognizers {
            for gestureRecognizer in existingGestures {
                if let existingLongPress = gestureRecognizer as? UILongPressGestureRecognizer {
                    existingLongPress.require(toFail: longPress)
                }
            }
        }

        collectionView.addGestureRecognizer(longPress)
        collectionView.addGestureRecognizer(panGesture)
    }

    private func removeGestureRecognizers() {
        if let longPress = longPress {
            safeCollectionView?.removeGestureRecognizer(longPress)
            self.longPress = nil
        }

        if let panGesture = panGesture {
            safeCollectionView?.removeGestureRecognizer(panGesture)
            self.panGesture = nil
        }
    }

    public func cancelDrag() {
        endDrag(nil)
    }

    private func shortestColumnIndex(_ columnHeights: [CGFloat]) -> Int {
        return columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
    }
}

// MARK: - UIGestureRecognizerDelegate
extension MasonryReorderableLayout: UIGestureRecognizerDelegate {
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let collectionView = safeCollectionView else { return false }

        let location = gestureRecognizer.location(in: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: location),
           delegate?.collectionView(collectionView, allowMoveAt: indexPath) == false {
            return false
        }

        if gestureRecognizer == longPress {
            return !(collectionView.panGestureRecognizer.state != .possible &&
                     collectionView.panGestureRecognizer.state != .failed)
        } else if gestureRecognizer == panGesture {
            guard let longPress = longPress else { return false }
            return !(longPress.state == .possible || longPress.state == .failed)
        }

        return true
    }

    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer == panGesture {
            return otherGestureRecognizer == longPress
        } else if gestureRecognizer == safeCollectionView?.panGestureRecognizer {
            guard let longPress = longPress else { return false }
            return longPress.state != .possible || longPress.state != .failed
        }

        return true
    }
}

// swiftlint:enable file_length
