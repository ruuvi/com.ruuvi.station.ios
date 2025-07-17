import UIKit
import RuuviOntology

// MARK: - Measurement View Controller (Combined with Page Controller)
final class CardsMeasurementViewController: UIViewController {

    // MARK: - Properties
    var output: CardsMeasurementViewOutput?

    // MARK: - State
    private var allSnapshots: [RuuviTagCardSnapshot] = []
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
        output?.measurementViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.measurementViewDidBecomeActive()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear

        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.fillSuperview()
        pageViewController.didMove(toParent: self)
    }

    // MARK: - Navigation Methods
    func navigateToIndex(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < allSnapshots.count && index != currentIndex else { return }

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

    // MARK: - Page Creation
    private func createCardsMeasurementPageViewController(for index: Int) -> CardsMeasurementPageViewController? {
        guard index >= 0 && index < allSnapshots.count else {
            return nil
        }

        let pageVC = CardsMeasurementPageViewController()
        pageVC.pageIndex = index
        pageVC.configure(with: allSnapshots[index])
        pageVC.delegate = self
        return pageVC
    }

    // MARK: - Initial Setup
    private func setupInitialPage() {
        guard !allSnapshots.isEmpty,
              currentIndex >= 0 && currentIndex < allSnapshots.count,
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
        if isRebuildingPageViewController || allSnapshots.isEmpty {
            return false
        }

        if currentIndex < 0 || currentIndex >= allSnapshots.count {
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
        output?.measurementViewDidChangeSnapshotIndex(currentIndex)
    }
}

// MARK: - CardsMeasurementViewInput
extension CardsMeasurementViewController: CardsMeasurementViewInput {

    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        // Single snapshot mode for backward compatibility ONLY
        // This should only be called during initial setup, not for updates
        if let snapshot = snapshot {
            allSnapshots = [snapshot]
            currentIndex = 0
            setupInitialPage()
        }
    }

    func updateMeasurementData() {
        // Only check state if we have snapshots and no valid current page
        if !allSnapshots.isEmpty && pageViewController.viewControllers?.isEmpty == true {
            ensureValidPageViewControllerState()
        } else if currentIndex < allSnapshots.count,
                  let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController {
            // Just update the existing page content
            currentPageVC.configure(with: allSnapshots[currentIndex])
        }
    }

    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], currentIndex: Int) {
        let oldCount = allSnapshots.count
        let oldIndex = self.currentIndex

        allSnapshots = snapshots
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
                   self.currentIndex < allSnapshots.count {
                    currentPageVC.configure(with: allSnapshots[self.currentIndex])
                }
                return
            }

            lastRebuildTime = now
            setupInitialPage()
        } else {
            // Just update existing page content
            if let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
               self.currentIndex < allSnapshots.count {
                currentPageVC.configure(with: allSnapshots[self.currentIndex])
            }
        }
    }

    // NEW: Update single snapshot data without rebuilding
    func updateCurrentSnapshotData(_ snapshot: RuuviTagCardSnapshot) {
        // Find and update the specific snapshot in our array
        if let index = allSnapshots.firstIndex(where: { $0.id == snapshot.id }) {
            allSnapshots[index] = snapshot

            // If it's the currently displayed page, update it
            if index == currentIndex,
               let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController {
                currentPageVC.configure(with: snapshot)
            }
        }
    }

    func presentIndicatorDetailsSheet(for indicator: RuuviTagCardSnapshotIndicatorData) {
        let bottomSheetVC = CardsIndicatorDetailsSheetView.createSheet(
            from: indicator
        )
        presentDynamicBottomSheet(vc: bottomSheetVC)
    }
}

// MARK: - UIPageViewControllerDataSource
extension CardsMeasurementViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard allSnapshots.count > 1 else {
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
        guard allSnapshots.count > 1 else {
            return nil
        }

        guard let pageVC = viewController as? CardsMeasurementPageViewController else {
            return nil
        }

        let targetIndex = pageVC.pageIndex + 1
        guard targetIndex < allSnapshots.count else {
            return nil
        }

        return createCardsMeasurementPageViewController(for: targetIndex)
    }
}

// MARK: - UIPageViewControllerDelegate
extension CardsMeasurementViewController: UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
              currentVC.pageIndex >= 0 && currentVC.pageIndex < allSnapshots.count else {
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
extension CardsMeasurementViewController: CardsMeasurementPageViewControllerDelegate {

    func cardsPageDidSelectMeasurement(
        _ type: MeasurementType,
        in pageViewController: CardsMeasurementPageViewController
    ) {
        output?.measurementViewDidSelectMeasurement(type)
    }
}
