import RuuviLocalization
import RuuviUser
import UIKit

// swiftlint:disable file_length

protocol RuuviOnboardViewControllerOutput: AnyObject {
    func ruuviOnboardPages(
        _ viewController: RuuviOnboardViewController,
        didFinish sender: Any?
    )
    func ruuviOnboardCloudSignIn(
        _ viewController: RuuviOnboardViewController,
        didPresentSignIn sender: Any?
    )
    func ruuviOnboardAnalytics(
        _ viewController: RuuviOnboardViewController,
        didProvideAnalyticsConsent isConsentGiven: Bool,
        sender: Any?
    )
}

enum OnboardPageType: Int {
    case measure = 0
    case dashboard = 1
    case sensors = 2
    case history = 3
    case alerts = 4
    case share = 5
    case widgets = 6
    case web = 7
    case signIn = 8
}

struct OnboardViewModel {
    var pageType: OnboardPageType
    var title: String
    var subtitle: String?
    var sub_subtitle: String?
    var image: UIImage?
}

class RuuviOnboardViewController: UIViewController {
    var output: RuuviOnboardViewControllerOutput?
    var ruuviUser: RuuviUser?
    var tosAccepted: Bool = false
    var analyticsConsentGiven: Bool = false

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var bgLayer: UIImageView = {
        let iv = UIImageView(image: RuuviAsset.commonBgLayer.image)
        iv.backgroundColor = .clear
        return iv
    }()

    private lazy var pageControl: UIPageControl = {
        let pc = UIPageControl()
        pc.currentPageIndicatorTintColor = .white
        pc.pageIndicatorTintColor = .lightGray
        pc.currentPage = 0
        pc.isUserInteractionEnabled = false
        return pc
    }()

    private lazy var skipButton: UIButton = {
        let button = UIButton()
        button.setTitleColor(.white, for: .normal)
        button.setTitle(RuuviLocalization.onboardingSkip, for: .normal)
        button.titleLabel?.font = UIFont.mulish(.bold, size: 14)
        button.addTarget(
            self,
            action: #selector(handleSkipButtonTap),
            for: .touchUpInside
        )
        button.underline()
        return button
    }()

    /// Re-size the pages and re-align to the current page after the next layout pass.
    private var needsPageRealignment = false

    /// The collection view size the pages were last laid out for (`.zero` before the first layout).
    private var laidOutPageSize: CGSize = .zero
    /// Keeps the header (page control and Skip) clear of the iPadOS window controls.
    private var headerWindowControlsInset: RuuviWindowControlsInsetUpdater?

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: layout
        )
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.dataSource = self
        cv.isPagingEnabled = true
        cv.showsHorizontalScrollIndicator = false
        return cv
    }()

    // -------------------------------
    private static let reuseIdentifierMeasure: String = "reuseIdentifierMeasure"
    private static let reuseIdentifierCoreFeatures: String = "reuseIdentifierCoreFeatures"
    private static let reuseIdentifierGatewayFeatures: String = "reuseIdentifierGatewayFeatures"
    private static let reuseIdentifierSignIn: String = "reuseIdentifierSignIn"

    private var viewModels: [OnboardViewModel] = [] {
        didSet {
            pageControl.numberOfPages = viewModels.count
            collectionView.reloadData()
            if tosAccepted && !analyticsConsentGiven {
                scrollToLast()
            }
        }
    }

    private var currentPage: Int = 0 {
        didSet {
            updateSkipButtonState()
        }
    }
}

extension RuuviOnboardViewController {
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // With side safe-area insets (iPhone Duo's vertical bar or side status bar, a side notch)
        // the paging scroll view would by default absorb them as horizontal content inset: every
        // page is then offset and its text runs under the bar. Without that adjustment the pages
        // stay full width (backgrounds edge to edge) and their content follows the safe area, as it
        // already does at the top and bottom. Switched only once side insets appear, so portrait
        // iPhones and full-screen iPads (no side insets) keep exactly their current behaviour.
        let insets = view.safeAreaInsets
        if insets.left > 0 || insets.right > 0,
           collectionView.contentInsetAdjustmentBehavior != .never {
            collectionView.contentInsetAdjustmentBehavior = .never
            needsPageRealignment = true
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        headerWindowControlsInset?.update()
        // Every page is as large as the view. After a size change (window resize, live resizing,
        // rotation, iPhone Duo display change) the pages must be re-sized and the offset re-aligned
        // to the current page, or the view ends up between pages or on another page. The first
        // layout only records the size; full-screen iPhones and iPads never change it afterwards.
        let pageSize = collectionView.bounds.size
        if pageSize != laidOutPageSize {
            if laidOutPageSize != .zero {
                needsPageRealignment = true
            }
            laidOutPageSize = pageSize
        }
        if needsPageRealignment {
            needsPageRealignment = false
            scrollToPage(currentPage)
        }
    }

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        // Rotation or a display change resizes the pages; stay on the page shown now (also when
        // the size changes mid-swipe, before `currentPage` is updated). The layout pass of the new
        // size realigns to `currentPage` too.
        let page = visiblePage()
        currentPage = page
        pageControl.currentPage = page
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.scrollToPage(page)
        }, completion: { [weak self] _ in
            self?.scrollToPage(page)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        viewModels = constructOnboardingPages()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

extension RuuviOnboardViewController {
    private func isUserAuthorized() -> Bool {
        guard let isAuthorized = ruuviUser?.isAuthorized
        else {
            return false
        }
        return isAuthorized
    }
}

extension RuuviOnboardViewController {
    @objc private func handleSkipButtonTap() {
        scrollToLast()
    }

    /// The page currently shown, from the scroll position.
    private func visiblePage() -> Int {
        let width = collectionView.bounds.width
        guard width > 0, !viewModels.isEmpty else { return currentPage }
        let page = Int((collectionView.contentOffset.x / width).rounded())
        return max(0, min(viewModels.count - 1, page))
    }

    /// Re-sizes the pages for the current size and shows `page`.
    private func scrollToPage(_ page: Int) {
        guard page < collectionView.numberOfItems(inSection: 0) else { return }
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        let width = collectionView.bounds.width
        guard width > 0 else { return }
        // Pages scroll horizontally only; keep the vertical resting offset (0 without insets).
        collectionView.setContentOffset(
            CGPoint(x: CGFloat(page) * width, y: -collectionView.adjustedContentInset.top),
            animated: false
        )
        currentPage = page
        pageControl.currentPage = page
    }

    private func scrollToLast() {
        collectionView.layoutIfNeeded()
        guard collectionView.numberOfItems(inSection: 0) > 0 else { return }
        let lastPageIndex = viewModels.count - 1
        currentPage = lastPageIndex
        pageControl.currentPage = lastPageIndex
        let indexPath = IndexPath(item: lastPageIndex, section: 0)
        collectionView.scrollToItem(
            at: indexPath,
            at: .centeredHorizontally,
            animated: false
        )
    }

    private func updateSkipButtonState() {
        skipButton.isHidden = currentPage == viewModels.count - 1
    }

    private func showDiscoverPage() {
        viewModels = constructOnboardingPages()
        guard isUserAuthorized()
        else {
            return
        }
        navigationController?.setNavigationBarHidden(false, animated: false)
        output?.ruuviOnboardPages(self, didFinish: nil)
    }
}

extension RuuviOnboardViewController: UICollectionViewDataSource {
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
        let viewModel = viewModels[indexPath.item]
        guard let cell = cell(
            collectionView: collectionView,
            indexPath: indexPath,
            viewModel: viewModel
        )
        else {
            fatalError()
        }

        return cell
    }
}

extension RuuviOnboardViewController: UICollectionViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let xPoint = scrollView.contentOffset.x + scrollView.frame.size.width / 2
        let yPoint = scrollView.frame.size.height / 2
        let center = CGPoint(x: xPoint, y: yPoint)
        if let currentIndexPath = collectionView.indexPathForItem(at: center) {
            currentPage = currentIndexPath.item
            pageControl.currentPage = currentIndexPath.item
        }
    }
}

extension RuuviOnboardViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt _: IndexPath
    ) -> CGSize {
        CGSize(width: view.bounds.width, height: view.bounds.height)
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        minimumLineSpacingForSectionAt _: Int
    ) -> CGFloat {
        0
    }
}

extension RuuviOnboardViewController {
    private func cell(
        collectionView: UICollectionView,
        indexPath: IndexPath,
        viewModel: OnboardViewModel
    ) -> UICollectionViewCell? {
        switch viewModel.pageType {
        case .measure:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.reuseIdentifierMeasure,
                for: indexPath
            ) as? RuuviOnboardStartCell
            cell?.configure(with: viewModel)
            return cell
        case .dashboard, .sensors, .history, .alerts:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.reuseIdentifierCoreFeatures,
                for: indexPath
            ) as? RuuviOnboardCoreFeaturesCell
            cell?.configure(with: viewModel)
            return cell
        case .share, .widgets, .web:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.reuseIdentifierGatewayFeatures,
                for: indexPath
            ) as? RuuviOnboardGatewayFeaturesCell
            cell?.configure(with: viewModel)
            return cell
        case .signIn:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: Self.reuseIdentifierSignIn,
                for: indexPath
            ) as? RuuviOnboardSignInCell
            cell?.delegate = self
            cell?.configure(
                with: viewModel,
                tosAccepted: tosAccepted
            )
            return cell
        }
    }
}

extension RuuviOnboardViewController: RuuviOnboardSignInCellDelegate {
    func didTapContinueButton(sender _: RuuviOnboardSignInCell) {
        if let authorized = ruuviUser?.isAuthorized, authorized {
            showDiscoverPage()
        } else {
            output?.ruuviOnboardCloudSignIn(self, didPresentSignIn: nil)
        }
    }

    func didProvideAnalyticsConsent(
        isConsentGiven: Bool,
        sender: RuuviOnboardSignInCell
    ) {
        output?.ruuviOnboardAnalytics(
            self,
            didProvideAnalyticsConsent: isConsentGiven,
            sender: nil
        )
    }
}

extension RuuviOnboardViewController {
    private func setUpUI() {
        setUpBase()
        setUpContentBody()
        setUpHeaderView()
    }

    private func setUpBase() {
        view.addSubview(bgLayer)
        bgLayer.fillSuperview()
    }

    private func setUpContentBody() {
        view.addSubview(collectionView)
        collectionView.fillSuperview()

        collectionView.register(
            RuuviOnboardStartCell.self,
            forCellWithReuseIdentifier: Self.reuseIdentifierMeasure
        )
        collectionView.register(
            RuuviOnboardCoreFeaturesCell.self,
            forCellWithReuseIdentifier: Self.reuseIdentifierCoreFeatures
        )
        collectionView.register(
            RuuviOnboardGatewayFeaturesCell.self,
            forCellWithReuseIdentifier: Self.reuseIdentifierGatewayFeatures
        )
        collectionView.register(
            RuuviOnboardSignInCell.self,
            forCellWithReuseIdentifier: Self.reuseIdentifierSignIn
        )
    }

    private func setUpHeaderView() {
        let headerView = UIView(color: .clear)
        view.addSubview(headerView)
        let headerConstraints = headerView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeadingAnchor,
            bottom: nil,
            trailing: view.safeTrailingAnchor,
            padding: .init(top: 0, left: 12, bottom: 0, right: 12),
            size: .init(width: 0, height: 44)
        )
        // Replaces the navigation bar: its leading edge moves clear of the window controls of an
        // iPadOS window that doesn't fill the screen (unchanged on iPhone and full-screen iPad).
        if let leading = headerConstraints.leading {
            headerWindowControlsInset = RuuviWindowControlsInsetUpdater(constraint: leading, in: view)
        }

        headerView.addSubview(pageControl)
        pageControl.centerInSuperview()

        headerView.addSubview(skipButton)
        skipButton.anchor(
            top: nil,
            leading: nil,
            bottom: nil,
            trailing: headerView.trailingAnchor
        )
        skipButton.centerYInSuperview()
    }
}

private extension RuuviOnboardViewController {
    static func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (
            _: Int,
            _: NSCollectionLayoutEnvironment
        )
            -> NSCollectionLayoutSection? in
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(1)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

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

    // swiftlint:disable:next function_body_length
    func constructOnboardingPages() -> [OnboardViewModel] {
        let meaureItem = OnboardViewModel(
            pageType: .measure,
            title: RuuviLocalization.onboardingMeasureYourWorld,
            subtitle: RuuviLocalization.onboardingWithRuuviSensors,
            sub_subtitle: RuuviLocalization.onboardingSwipeToContinue
        )

        let dashboardItem = OnboardViewModel(
            pageType: .dashboard,
            title: RuuviLocalization.onboardingDashboard,
            subtitle: RuuviLocalization.onboardingFollowMeasurement,
            image: RuuviAsset.Onboarding.onboardingDashboard.image
        )

        let sensorItem = OnboardViewModel(
            pageType: .sensors,
            title: RuuviLocalization.onboardingYourSensors,
            subtitle: RuuviLocalization.onboardingPersonalise,
            image: RuuviAsset.Onboarding.onboardingSensors.image
        )

        let historyItem = OnboardViewModel(
            pageType: .history,
            title: RuuviLocalization.onboardingHistory,
            subtitle: RuuviLocalization.onboardingExploreDetailed,
            image: RuuviAsset.Onboarding.onboardingHistory.image
        )

        let alertItem = OnboardViewModel(
            pageType: .alerts,
            title: RuuviLocalization.onboardingAlerts,
            subtitle: RuuviLocalization.onboardingSetCustom,
            image: RuuviAsset.Onboarding.onboardingAlerts.image
        )

        let shareItem = OnboardViewModel(
            pageType: .share,
            title: RuuviLocalization.onboardingShareYourSensors,
            subtitle: RuuviLocalization.onboardingShareesCanUse,
            image: RuuviAsset.Onboarding.onboardingShare.image
        )

        let widgetItem = OnboardViewModel(
            pageType: .widgets,
            title: RuuviLocalization.onboardingHandyWidgets,
            subtitle: RuuviLocalization.onboardingAccessWidgets,
            image: RuuviAsset.Onboarding.onboardingWidgets.image
        )

        let webItem = OnboardViewModel(
            pageType: .web,
            title: RuuviLocalization.onboardingStationWeb,
            subtitle: RuuviLocalization.onboardingWebPros,
            image: RuuviAsset.Onboarding.onboardingWeb.image
        )

        let signInItem = OnboardViewModel(
            pageType: .signIn,
            title: isUserAuthorized() ?
            RuuviLocalization.onboardingThatsItAlreadySignedIn :
                RuuviLocalization.onboardingThatsIt,
            subtitle: nil
        )

        return [
            meaureItem,
            dashboardItem,
            sensorItem,
            historyItem,
            alertItem,
            shareItem,
            widgetItem,
            webItem,
            signInItem,
        ]
    }
}
