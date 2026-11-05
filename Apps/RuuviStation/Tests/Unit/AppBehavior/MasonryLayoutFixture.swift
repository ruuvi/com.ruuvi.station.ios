import RuuviOntology
import UIKit
import XCTest
@testable import station

@MainActor final class MasonryLayoutFixture {
    let layout = MasonryReorderableLayout()
    let delegate = MasonryDelegateSpy()
    let collection: UICollectionView
    let dataSource: UICollectionViewDiffableDataSource<MasonrySection, RuuviTagCardSnapshot>
    var items = [RuuviTagCardSnapshot]()
    var window: UIWindow?
    private var previousWindow: UIWindow?
    init(count: Int = 8, size: CGSize = CGSize(width: 402, height: 650), columns: Int = 2) {
        delegate.columns = columns
        collection = UICollectionView(frame: CGRect(origin: .zero, size: size), collectionViewLayout: layout)
        collection.contentInsetAdjustmentBehavior = .never
        collection.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Sensor")
        dataSource = UICollectionViewDiffableDataSource(collectionView: collection) { view, index, _ in
            let cell = view.dequeueReusableCell(withReuseIdentifier: "Sensor", for: index)
            cell.backgroundColor = index.item.isMultiple(of: 2) ? .systemBlue : .systemGreen
            return cell
        }
        layout.delegate = delegate
        layout.setDataSource(dataSource)
        for index in 0..<count {
            items.append(
                .create(
                    id: "layout-\(index)", name: "Room \(index)", luid: "layout-\(index)".luid,
                    mac: nil, serviceUUID: nil, isCloud: false, isOwner: true, isConnectable: true, version: 5))
        }
        var snapshot = NSDiffableDataSourceSnapshot<MasonrySection, RuuviTagCardSnapshot>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items)
        dataSource.apply(snapshot, animatingDifferences: false)
        collection.layoutIfNeeded()
    }
    func host() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        previousWindow = scene.windows.first(where: \.isKeyWindow)
        let host = UIWindow(windowScene: scene)
        let controller = UIViewController()
        host.rootViewController = controller
        controller.view.addSubview(collection)
        host.makeKeyAndVisible()
        collection.layoutIfNeeded()
        window = host
    }
    func unhost() {
        collection.removeFromSuperview()
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        previousWindow?.makeKeyAndVisible()
    }
    func begin(_ index: Int) throws -> CGPoint {
        let attributes = try XCTUnwrap(layout.layoutAttributesForItem(at: IndexPath(item: index, section: 0)))
        let gesture = MasonryLongPress()
        gesture.point = attributes.center
        gesture.state = .began
        layout.handleLongPress(gesture)
        collection.layoutIfNeeded()
        return attributes.center
    }
    func move(from point: CGPoint, to target: CGPoint, state: UIGestureRecognizer.State = .changed) {
        let gesture = MasonryPan()
        gesture.point = target
        gesture.offset = CGPoint(x: target.x - point.x, y: target.y - point.y)
        gesture.state = state
        layout.handlePanGesture(gesture)
        collection.layoutIfNeeded()
    }
}

final class MasonryLongPress: UILongPressGestureRecognizer {
    var simulatedState: UIGestureRecognizer.State = .possible
    var point = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { point }
}
final class MasonryPan: UIPanGestureRecognizer {
    var simulatedState: UIGestureRecognizer.State = .possible
    var point = CGPoint.zero
    var offset = CGPoint.zero
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
    override func location(in view: UIView?) -> CGPoint { point }
    override func translation(in view: UIView?) -> CGPoint { offset }
}

final class MasonryDelegateSpy: MasonryReorderableLayoutDelegate {
    var columns = 2
    var spacing: CGFloat = 12
    var insets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
    var heights = [CGFloat]()
    var allow = true
    var allowDestination = true
    var starts = [IndexPath]()
    var ends = [IndexPath]()
    var willMoves = [(IndexPath, IndexPath)]()
    var didMoves = [(IndexPath, IndexPath)]()
    var orders = [[String]]()
    func numberOfColumns(in collectionView: UICollectionView) -> Int { columns }
    func columnSpacing(in collectionView: UICollectionView) -> CGFloat { spacing }
    func sectionInsets(in collectionView: UICollectionView) -> UIEdgeInsets { insets }
    func collectionView(_ collectionView: UICollectionView, heightForItemAt indexPath: IndexPath) -> CGFloat {
        heights.indices.contains(indexPath.item) ? heights[indexPath.item] : 100
    }
    func collectionView(_ collectionView: UICollectionView, allowMoveAt indexPath: IndexPath) -> Bool { allow }
    func collectionView(_ collectionView: UICollectionView, at: IndexPath, canMoveTo: IndexPath) -> Bool {
        allowDestination
    }
    func collectionView(_ collectionView: UICollectionView, at: IndexPath, willMoveTo to: IndexPath) {
        willMoves.append((at, to))
    }
    func collectionView(
        _ collectionView: UICollectionView, at: IndexPath, didMoveTo to: IndexPath,
        currentSnapshots: [RuuviTagCardSnapshot]
    ) {
        didMoves.append((at, to)); orders.append(currentSnapshots.map(\.id))
    }
    func collectionView(
        _ collectionView: UICollectionView, layout: MasonryReorderableLayout,
        didBeginDraggingItemAt indexPath: IndexPath
    ) { starts.append(indexPath) }
    func collectionView(
        _ collectionView: UICollectionView, layout: MasonryReorderableLayout,
        didEndDraggingItemTo indexPath: IndexPath
    ) { ends.append(indexPath) }
}
