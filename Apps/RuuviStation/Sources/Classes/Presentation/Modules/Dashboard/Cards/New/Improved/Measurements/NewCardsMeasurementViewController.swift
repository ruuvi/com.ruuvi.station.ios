import UIKit
import RuuviOntology

// MARK: - Measurement View Controller
// View that holds a PageViewController for each Snapshot.
class NewCardsMeasurementViewController: UIViewController {

    // MARK: - Properties
    weak var output: NewCardsMeasurementViewOutput?

    // MARK: - State
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var currentIndex: Int = 0
    private var isRebuildingPageViewController = false
    private var lastRebuildTime: Date = Date.distantPast

    // MARK: - UI Components - Page View Controller
    private lazy var pageViewController: UIPageViewController = {
        let pageVC = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pageVC.dataSource = self
        pageVC.delegate = self
        return pageVC
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.viewWillAppear(sender: self)
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.fillSuperview()
        pageViewController.didMove(toParent: self)
    }

    // MARK: - Page Creation
    private func createCardsMeasurementPageViewController(
        for index: Int
    ) -> CardsMeasurementPageViewController? {
        guard index >= 0 && index < snapshots.count else {
            return nil
        }

        let pageVC = CardsMeasurementPageViewController()
        pageVC.pageIndex = index
        pageVC.configure(with: snapshots[index])
        pageVC.delegate = self
        return pageVC
    }

    // MARK: - Initial Setup
    private func setupInitialPage() {
        guard !snapshots.isEmpty,
              currentIndex >= 0 && currentIndex < snapshots.count,
              let initialVC = createCardsMeasurementPageViewController(for: currentIndex) else {
            return
        }

        pageViewController.setViewControllers(
            [initialVC],
            direction: .forward,
            animated: false
        )
    }

    // MARK: - State Validation and Recovery
    private func shouldRebuildPageViewController() -> Bool {
        if isRebuildingPageViewController || snapshots.isEmpty {
            return false
        }

        if currentIndex < 0 || currentIndex >= snapshots.count {
            return true
        }

        guard let currentVCs = pageViewController.viewControllers, !currentVCs.isEmpty else {
            return true
        }

        guard let currentPageVC = currentVCs.first as? CardsMeasurementPageViewController else {
            return true
        }

        if currentPageVC.pageIndex != currentIndex {
            return true
        }

        return false
    }

    private func ensureValidPageViewControllerState() {
        guard shouldRebuildPageViewController() else {
            return
        }

        isRebuildingPageViewController = true
        setupInitialPage()
        isRebuildingPageViewController = false
    }

    // MARK: - Index Change Notification
    private func notifyIndexChange() {
        output?.viewDidScroll(to: currentIndex, sender: self)
    }
}

// MARK: - NewCardsMeasurementViewInput
extension NewCardsMeasurementViewController: NewCardsMeasurementViewInput {
    func updateSnapshots(
        _ snapshots: [RuuviTagCardSnapshot],
        currentIndex: Int
    ) {
        let oldCount = snapshots.count
        let oldIndex = self.currentIndex

        self.snapshots = snapshots
        self.currentIndex = max(0, min(currentIndex, snapshots.count - 1))

        if snapshots.isEmpty {
            pageViewController.setViewControllers([], direction: .forward, animated: false)
            return
        }

        let isFirstTime = oldCount == 0
        let countChanged = oldCount != snapshots.count
        let indexChanged = self.currentIndex != oldIndex
        let stateInvalid = shouldRebuildPageViewController()

        let needsRebuild = isFirstTime || countChanged || indexChanged || stateInvalid

        if needsRebuild {
            // Add throttling - don't rebuild more than once per 100ms
            let now = Date()
            let timeSinceLastRebuild = now.timeIntervalSince(lastRebuildTime)

            if timeSinceLastRebuild < 0.1 {
                // Just update content instead
                if let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
                   self.currentIndex < snapshots.count {
                    currentPageVC.configure(with: snapshots[self.currentIndex])
                }
                return
            }

            lastRebuildTime = now
            setupInitialPage()
        } else {
            // Just update existing page content
            if let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
               self.currentIndex < snapshots.count {
                currentPageVC.configure(with: snapshots[self.currentIndex])
            }
        }

    }

//    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot) {
//        if let index = snapshots.firstIndex(where: { $0.id == snapshot.id }) {
//            snapshots[index] = snapshot
//
//            // If it's the currently displayed page, update it
//            if index == currentIndex,
//               let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController {
//                currentPageVC.configure(with: snapshot)
//            }
//        }
//    }

    func navigateToIndex(_ index: Int, animated: Bool) {
        guard index >= 0 && index < snapshots.count && index != currentIndex else {
            return
        }

        let direction: UIPageViewController.NavigationDirection = index > currentIndex ? .forward : .reverse
        currentIndex = index

        if let targetVC = createCardsMeasurementPageViewController(for: index) {
            pageViewController.setViewControllers(
                [targetVC],
                direction: direction,
                animated: animated
            ) { [weak self] finished in
                if finished {
                    self?.notifyIndexChange()
                }
            }
        }
    }
}

// MARK: - UIPageViewControllerDataSource
extension NewCardsMeasurementViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard snapshots.count > 1 else {
            return nil
        }

        guard let pageVC = viewController as? CardsMeasurementPageViewController else {
            return nil
        }

        let targetIndex = pageVC.pageIndex - 1
        guard targetIndex >= 0 else {
            return nil
        }

        return createCardsMeasurementPageViewController(for: targetIndex)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard snapshots.count > 1 else {
            return nil
        }

        guard let pageVC = viewController as? CardsMeasurementPageViewController else {
            return nil
        }

        let targetIndex = pageVC.pageIndex + 1
        guard targetIndex < snapshots.count else {
            return nil
        }

        return createCardsMeasurementPageViewController(for: targetIndex)
    }
}

// MARK: - UIPageViewControllerDelegate
extension NewCardsMeasurementViewController: UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
              currentVC.pageIndex >= 0 && currentVC.pageIndex < snapshots.count else {
            return
        }

        let newIndex = currentVC.pageIndex
        if newIndex != currentIndex {
            currentIndex = newIndex
            notifyIndexChange()
        }
    }
}

// MARK: - CardsMeasurementPageViewControllerDelegate
extension NewCardsMeasurementViewController: CardsMeasurementPageViewControllerDelegate {
    func cardsPageDidSelectMeasurementIndicator(
        _ indicator: RuuviTagCardSnapshotIndicatorData,
        in pageViewController: CardsMeasurementPageViewController
    ) {
        let bottomSheetVC = CardsIndicatorDetailsSheetView.createSheet(
            from: indicator
        )
        presentDynamicBottomSheet(vc: bottomSheetVC)
    }
}
