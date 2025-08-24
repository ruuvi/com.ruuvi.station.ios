import UIKit
import RuuviOntology
import RuuviService

// MARK: - Main Measurement View Controller
final class CardsMeasurementViewController: UIViewController {

    // MARK: - Constants
    private enum Constants {
        static let rebuildThrottleInterval: TimeInterval = 0.1
    }

    // MARK: - Properties
    weak var output: CardsMeasurementViewOutput?

    // MARK: - State Management
    private var snapshots: [RuuviTagCardSnapshot] = []
    private var currentIndex: Int = 0
    private var isRebuildingPageViewController = false
    private var lastRebuildTime: Date = Date.distantPast

    // MARK: - UI Components
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
}

// MARK: - Setup Methods
private extension CardsMeasurementViewController {

    func setupUI() {
        view.backgroundColor = .clear
        configurePageViewController()
    }

    func configurePageViewController() {
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.view.fillSuperview()
        pageViewController.didMove(toParent: self)
    }
}

// MARK: - Page Creation and Management
private extension CardsMeasurementViewController {

    func createCardsMeasurementPageViewController(
        for index: Int
    ) -> CardsMeasurementPageViewController? {
        guard isValidIndex(index) else { return nil }

        let pageVC = CardsMeasurementPageViewController()
        pageVC.pageIndex = index
        pageVC.configure(with: snapshots[index])
        pageVC.delegate = self
        return pageVC
    }

    func setupInitialPage() {
        guard !snapshots.isEmpty,
              isValidIndex(currentIndex),
              let initialVC = createCardsMeasurementPageViewController(for: currentIndex) else {
            return
        }

        pageViewController.setViewControllers(
            [initialVC],
            direction: .forward,
            animated: false
        )
    }

    func isValidIndex(_ index: Int) -> Bool {
        return index >= 0 && index < snapshots.count
    }
}

// MARK: - State Validation and Recovery
private extension CardsMeasurementViewController {

    func shouldRebuildPageViewController() -> Bool {
        guard !isRebuildingPageViewController && !snapshots.isEmpty else {
            return false
        }

        if !isValidIndex(currentIndex) {
            return true
        }

        guard let currentVCs = pageViewController.viewControllers,
              !currentVCs.isEmpty,
              let currentPageVC = currentVCs.first as? CardsMeasurementPageViewController else {
            return true
        }

        return currentPageVC.pageIndex != currentIndex
    }

    func ensureValidPageViewControllerState() {
        guard shouldRebuildPageViewController() else { return }

        isRebuildingPageViewController = true
        setupInitialPage()
        isRebuildingPageViewController = false
    }

    func shouldThrottleRebuild() -> Bool {
        let now = Date()
        let timeSinceLastRebuild = now.timeIntervalSince(lastRebuildTime)
        return timeSinceLastRebuild < Constants.rebuildThrottleInterval
    }

    func performThrottledUpdate() {
        guard let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
              isValidIndex(currentIndex) else {
            return
        }

        currentPageVC.configure(with: snapshots[currentIndex])
    }

    func performFullRebuild() {
        lastRebuildTime = Date()
        setupInitialPage()
    }
}

// MARK: - Index Change Notification
private extension CardsMeasurementViewController {

    func notifyIndexChange() {
        output?.viewDidScroll(to: currentIndex, sender: self)
    }
}

// MARK: - CardsMeasurementViewInput
extension CardsMeasurementViewController: CardsMeasurementViewInput {

    func updateSnapshots(
        _ snapshots: [RuuviTagCardSnapshot],
        currentIndex: Int
    ) {
        let oldCount = self.snapshots.count
        let oldIndex = self.currentIndex

        self.snapshots = snapshots
        self.currentIndex = max(0, min(currentIndex, snapshots.count - 1))

        guard !snapshots.isEmpty else {
            pageViewController.setViewControllers([], direction: .forward, animated: false)
            return
        }

        let needsRebuild = shouldPerformRebuild(
            oldCount: oldCount,
            oldIndex: oldIndex
        )

        if needsRebuild {
            handleRebuildRequest()
        } else {
            updateExistingPageContent()
        }
    }

    func navigateToIndex(_ index: Int, animated: Bool) {
        guard isValidIndex(index) && index != currentIndex else { return }

        let direction: UIPageViewController.NavigationDirection =
                index > currentIndex ? .forward : .reverse
        currentIndex = index

        guard let targetVC = createCardsMeasurementPageViewController(for: index) else { return }

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

// MARK: - Update Logic Helpers
private extension CardsMeasurementViewController {

    func shouldPerformRebuild(oldCount: Int, oldIndex: Int) -> Bool {
        let isFirstTime = oldCount == 0
        let countChanged = oldCount != snapshots.count
        let indexChanged = currentIndex != oldIndex
        let stateInvalid = shouldRebuildPageViewController()

        return isFirstTime || countChanged || indexChanged || stateInvalid
    }

    func handleRebuildRequest() {
        if shouldThrottleRebuild() {
            performThrottledUpdate()
        } else {
            performFullRebuild()
        }
    }

    func updateExistingPageContent() {
        guard let currentPageVC = pageViewController.viewControllers?.first as? CardsMeasurementPageViewController,
              isValidIndex(currentIndex) else {
            return
        }

        currentPageVC.configure(with: snapshots[currentIndex])
    }
}

// MARK: - UIPageViewControllerDataSource
extension CardsMeasurementViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard snapshots.count > 1,
              let pageVC = viewController as? CardsMeasurementPageViewController else {
            return nil
        }

        let targetIndex = pageVC.pageIndex - 1
        guard targetIndex >= 0 else { return nil }

        return createCardsMeasurementPageViewController(for: targetIndex)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard snapshots.count > 1,
              let pageVC = viewController as? CardsMeasurementPageViewController else {
            return nil
        }

        let targetIndex = pageVC.pageIndex + 1
        guard targetIndex < snapshots.count else { return nil }

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
              isValidIndex(currentVC.pageIndex) else {
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

    func cardsPageDidSelectMeasurementIndicator(
        _ indicator: RuuviTagCardSnapshotIndicatorData,
        in pageViewController: CardsMeasurementPageViewController
    ) {
        let snapshot = snapshots[pageViewController.pageIndex]
        output?.viewDidTapMeasurement(for: indicator, snapshot: snapshot)
    }
}
