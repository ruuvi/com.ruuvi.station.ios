import UIKit
import RuuviUser
import RuuviBundleUtils

// swiftlint:disable file_length

protocol RuuviOnboardViewControllerOutput: AnyObject {
    func ruuviOnboardPages(_ viewController: RuuviOnboardViewController,
                           didFinish sender: Any?)
    func ruuviOnboardCloudSignIn(_ viewController: RuuviOnboardViewController,
                                 didPresentSignIn sender: Any?)
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
    var subtitle: String
    // swiftlint:disable redundant_optional_initialization
    var sub_subtitle: String? = nil
    var image: String? = nil
    // swiftlint:enable redundant_optional_initialization
}

class RuuviOnboardViewController: UIViewController {
    var output: RuuviOnboardViewControllerOutput?
    var ruuviUser: RuuviUser?

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var bgLayer: UIImageView = {
        let iv = UIImageView(image: UIImage.named(RuuviAssets.bg_layer,
                                                  for: Self.self))
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
        button.setTitle("onboarding_skip".localized(for: Self.self), for: .normal)
        button.titleLabel?.font = UIFont.Muli(.bold, size: 14)
        button.addTarget(self,
                         action: #selector(handleSkipButtonTap),
                         for: .touchUpInside)
        button.underline()
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        let cv = UICollectionView(frame: .zero,
                                  collectionViewLayout: layout)
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
        }
    }

    private var currentPage: Int = 0 {
        didSet {
            updateSkipButtonState()
        }
    }
}

extension RuuviOnboardViewController {

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
        guard let isAuthorized = ruuviUser?.isAuthorized else {
            return false
        }
        return isAuthorized
    }
}

extension RuuviOnboardViewController {
    @objc private func handleSkipButtonTap() {
        scrollToLast()
    }

    private func scrollToLast() {
        let lastPageIndex = viewModels.count - 1
        currentPage = lastPageIndex
        pageControl.currentPage = lastPageIndex
        let indexPath = IndexPath(item: lastPageIndex, section: 0)
        collectionView.scrollToItem(at: indexPath,
                                    at: .centeredHorizontally,
                                    animated: false)
    }

    private func updateSkipButtonState() {
        skipButton.isHidden = currentPage == viewModels.count - 1
    }

    private func showDiscoverPage() {
        viewModels = constructOnboardingPages()
        guard isUserAuthorized() else {
            return
        }
        navigationController?.setNavigationBarHidden(false, animated: false)
        output?.ruuviOnboardPages(self, didFinish: nil)
    }
}

extension RuuviOnboardViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return viewModels.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let viewModel = viewModels[indexPath.item]
        guard let cell = cell(collectionView: collectionView,
                              indexPath: indexPath,
                              viewModel: viewModel) else {
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
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return CGSize(width: view.bounds.width, height: view.bounds.height)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
}

extension RuuviOnboardViewController {

    private func cell(collectionView: UICollectionView,
                      indexPath: IndexPath,
                      viewModel: OnboardViewModel) -> UICollectionViewCell? {
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
            cell?.configure(with: viewModel)
            return cell
        default:
            return UICollectionViewCell()
        }

    }

}

extension RuuviOnboardViewController: RuuviOnboardSignInCellDelegate {
    func didTapContinueButton(sender: RuuviOnboardSignInCell) {
        if let authorized = ruuviUser?.isAuthorized, authorized {
            showDiscoverPage()
        } else {
            output?.ruuviOnboardCloudSignIn(self, didPresentSignIn: nil)
        }
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

        collectionView.register(RuuviOnboardStartCell.self,
                                forCellWithReuseIdentifier: Self.reuseIdentifierMeasure)
        collectionView.register(RuuviOnboardCoreFeaturesCell.self,
                                forCellWithReuseIdentifier: Self.reuseIdentifierCoreFeatures)
        collectionView.register(RuuviOnboardGatewayFeaturesCell.self,
                                forCellWithReuseIdentifier: Self.reuseIdentifierGatewayFeatures)
        collectionView.register(RuuviOnboardSignInCell.self,
                                forCellWithReuseIdentifier: Self.reuseIdentifierSignIn)
    }

    private func setUpHeaderView() {
        let headerView = UIView(color: .clear)
        view.addSubview(headerView)
        headerView.anchor(top: view.safeTopAnchor,
                          leading: view.safeLeadingAnchor,
                          bottom: nil,
                          trailing: view.safeTrailingAnchor,
                          padding: .init(top: 0, left: 12, bottom: 0, right: 12),
                          size: .init(width: 0, height: 44))

        headerView.addSubview(pageControl)
        pageControl.centerInSuperview()

        headerView.addSubview(skipButton)
        skipButton.anchor(top: nil,
                          leading: nil,
                          bottom: nil,
                          trailing: headerView.trailingAnchor)
        skipButton.centerYInSuperview()
    }
}

extension RuuviOnboardViewController {

    fileprivate static func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (_: Int,
                                 _: NSCollectionLayoutEnvironment)
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
    fileprivate func constructOnboardingPages() -> [OnboardViewModel] {

        let meaureItem = OnboardViewModel(
            pageType: .measure,
            title: "onboarding_measure_your_world".localized(for: Self.self),
            subtitle: "onboarding_with_ruuvi_sensors".localized(for: Self.self),
            sub_subtitle: "onboarding_swipe_to_continue".localized(for: Self.self)
        )

        let dashboardItem = OnboardViewModel(
            pageType: .dashboard,
            title: "onboarding_dashboard".localized(for: Self.self),
            subtitle: "onboarding_follow_measurement".localized(for: Self.self),
            image: RuuviAssets.dashboard
        )

        let sensorItem = OnboardViewModel(
            pageType: .sensors,
            title: "onboarding_your_sensors".localized(for: Self.self),
            subtitle: "onboarding_personalise".localized(for: Self.self),
            image: RuuviAssets.sensors
        )

        let historyItem = OnboardViewModel(
            pageType: .history,
            title: "onboarding_history".localized(for: Self.self),
            subtitle: "onboarding_explore_detailed".localized(for: Self.self),
            image: RuuviAssets.history
        )

        let alertItem = OnboardViewModel(
            pageType: .alerts,
            title: "onboarding_alerts".localized(for: Self.self),
            subtitle: "onboarding_set_custom".localized(for: Self.self),
            image: RuuviAssets.alerts
        )

        let shareItem = OnboardViewModel(
            pageType: .share,
            title: "onboarding_share_your_sensors".localized(for: Self.self),
            subtitle: "onboarding_sharees_can_use".localized(for: Self.self),
            image: RuuviAssets.share
        )

        let widgetItem = OnboardViewModel(
            pageType: .widgets,
            title: "onboarding_handy_widgets".localized(for: Self.self),
            subtitle: "onboarding_access_widgets".localized(for: Self.self),
            image: RuuviAssets.widgets
        )

        let webItem = OnboardViewModel(
            pageType: .web,
            title: "onboarding_station_web".localized(for: Self.self),
            subtitle: "onboarding_web_pros".localized(for: Self.self),
            image: RuuviAssets.web
        )

        let signInItem = OnboardViewModel(
            pageType: .signIn,
            title: isUserAuthorized() ?
                "onboarding_thats_it_already_signed_in".localized(for: Self.self) :
                "onboarding_thats_it".localized(for: Self.self),
            subtitle: isUserAuthorized() ?
                "onboarding_go_to_sign_in_already_signed_in".localized(for: Self.self) :
                "onboarding_go_to_sign_in".localized(for: Self.self)
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
            signInItem
        ]
    }
}
