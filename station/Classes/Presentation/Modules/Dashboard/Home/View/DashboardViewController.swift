// swiftlint:disable file_length
import UIKit
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService

// TODO: @prioyonto - Refactor this file and move things to constants.
enum DashboardSection: CaseIterable {
    case main
}

typealias DashboardSnapshot = NSDiffableDataSourceSnapshot<CardsSection, CardsViewModel>
typealias DashboardDataSource = UICollectionViewDiffableDataSource<CardsSection, CardsViewModel>

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

    private var layout: RuuviSimpleViewCompositionalLayout?
    private lazy var datasource = makeDatasource()
    // MARK: - Datasource
    private func makeDatasource() -> DashboardDataSource {
        let datasource = CardsDataSource(
            collectionView: collectionView,
            cellProvider: { [unowned self] (collectionView, indexPath, viewModel) in
                return self.cell(collectionView: collectionView,
                           indexPath: indexPath,
                           viewModel: viewModel)
            }
        )
        return datasource
    }

    func cell(collectionView: UICollectionView,
              indexPath: IndexPath,
              viewModel: CardsViewModel) -> UICollectionViewCell? {
        switch dashboardType {
        case .image:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellId",
                                                                for: indexPath) as? DashboardImageCell
            cell?.configure(with: viewModel, measurementService: measurementService)
            cell?.restartAlertAnimation(for: viewModel)
            cell?.delegate = self
            cell?.moreButton.menu = cardContextMenuOption(for: indexPath.item)
            return cell
        case .simple:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cellIdPlain",
                                                                for: indexPath) as? DashboardPlainCell
            cell?.configure(with: viewModel, measurementService: measurementService)
            cell?.restartAlertAnimation(for: viewModel)
            cell?.delegate = self
            cell?.moreButton.menu = cardContextMenuOption(for: indexPath.item)
            cell?.layout = layout
            return cell
        case .none:
            return nil
        }
    }

    func applySnapshot(_ items: [CardsViewModel]) {
        var snapshot = DashboardSnapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        datasource.apply(snapshot,
                         animatingDifferences: true)
    }

    // UI
    private lazy var noSensorView: NoSensorView = {
       let view = NoSensorView()
        view.backgroundColor = RuuviColor.dashboardCardBGColor
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.delegate = self
        return view
    }()

    // Header View
    // Ruuvi Logo
    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "ruuvi_logo_"),
                             contentMode: .scaleAspectFit)
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.logoTintColor
        return iv
    }()

    // Action Buttons
    private lazy var menuButton: UIButton = {
        let button  = UIButton()
        button.tintColor = RuuviColor.menuButtonTintColor
        let menuImage = UIImage(named: "baseline_menu_white_48pt")
        button.setImage(menuImage, for: .normal)
        button.setImage(menuImage, for: .highlighted)
        button.backgroundColor = .clear
        button.addTarget(self,
                         action: #selector(handleMenuButtonTap),
                         for: .touchUpInside)
        return button
    }()

    private lazy var viewButton: RuuviContextMenuButton =
        RuuviContextMenuButton(menu: viewToggleMenuOptions(),
                               titleColor: RuuviColor.dashboardIndicatorTextColor,
                               title: "view".localized(),
                               icon: UIImage(named: "dismiss-modal-icon"),
                               iconTintColor: RuuviColor.logoTintColor,
                               preccedingIcon: false)

    // BODY
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero,
                                  collectionViewLayout: createLayout())
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
        return cv
    }()

    private var appDidBecomeActiveToken: NSObjectProtocol?

    private var isListRefreshable: Bool = true
    /// The view model when context menu is presented after a card tap.
    private var highlightedViewModel: CardsViewModel?

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
}

// MARK: - View lifecycle
extension DashboardViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        setupLocalization()
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

    override func viewWillTransition(to size: CGSize,
                                     with coordinator:
                                     UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        reloadCollectionView(redrawLayout: true)
    }
}

extension DashboardViewController {
    @objc fileprivate func handleMenuButtonTap() {
        output.viewDidTriggerMenu()
    }

    private func reloadCollectionView(redrawLayout: Bool = false) {
        DispatchQueue.main.async { [weak self] in
            if redrawLayout {
                guard let self = self else { return }
                let flowLayout = self.createLayout()
                self.collectionView.setCollectionViewLayout(
                    flowLayout,
                    animated: false,
                    completion: { _ in
                        guard self.viewModels.count > 0 else { return }
                        let indexPath = IndexPath(item: 0, section: 0)
                        self.collectionView.scrollToItem(at: indexPath,
                                                          at: .top,
                                                          animated: false)
                        self.collectionView.contentOffset.y = -8
                    }
                )
            }
            self?.collectionView.reloadData()
        }
    }
}

extension DashboardViewController {
    private func viewToggleMenuOptions() -> UIMenu {
        let imageViewAction = UIAction(title: "image_view".localized()) { [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .image)
            self?.reloadCollectionView(redrawLayout: true)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let simpleViewAction = UIAction(title: "simple_view".localized()) { [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .simple)
            self?.reloadCollectionView(redrawLayout: true)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        if dashboardType == .image {
            simpleViewAction.state = .off
            imageViewAction.state = .on
        } else {
            imageViewAction.state = .off
            simpleViewAction.state = .on
        }

        return UIMenu(title: "",
                      children: [imageViewAction, simpleViewAction])
    }

    private func cardContextMenuOption(for index: Int) -> UIMenu {
        let fullImageViewAction = UIAction(title: "full_image_view".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerOpenCardImageView(for: viewModel)
            }
        }

        let historyViewAction = UIAction(title: "history_view".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChart(for: viewModel)
            }
        }

        let settingsAction = UIAction(title: "settings_and_alerts".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerSettings(for: viewModel,
                                                    with: false)
            }
        }

        let changeBackgroundAction = UIAction(title: "change_background".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChangeBackground(for: viewModel)
            }
        }

        return UIMenu(title: "",
                      children: [fullImageViewAction,
                                 historyViewAction,
                                 settingsAction,
                                 changeBackgroundAction])
    }
}

extension DashboardViewController {
    fileprivate func setUpUI() {
        updateNavBarTitleFont()
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
    }

    fileprivate func updateNavBarTitleFont() {
        navigationController?.navigationBar.titleTextAttributes =
            [NSAttributedString.Key.font: UIFont.Muli(.bold, size: 18)]
    }

    fileprivate func setUpBaseView() {
        view.backgroundColor = RuuviColor.dashboardBGColor

        view.addSubview(noSensorView)
        noSensorView.anchor(top: view.safeTopAnchor,
                            leading: view.safeLeftAnchor,
                            bottom: view.safeBottomAnchor,
                            trailing: view.safeRightAnchor,
                            padding: .init(top: 12,
                                           left: 12,
                                           bottom: 12,
                                           right: 12))
        noSensorView.isHidden = true
    }

    fileprivate func setUpHeaderView() {

        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(menuButton)
        menuButton.anchor(top: leftBarButtonView.topAnchor,
                          leading: leftBarButtonView.leadingAnchor,
                          bottom: leftBarButtonView.bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 0, left: 0, bottom: 0, right: 0),
                          size: .init(width: 32, height: 32))

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(top: nil,
                             leading: menuButton.trailingAnchor,
                             bottom: nil,
                             trailing: leftBarButtonView.trailingAnchor,
                             padding: .init(top: 0, left: 8, bottom: 0, right: 0),
                             size: .init(width: 110, height: 22))
        ruuviLogoView.centerYInSuperview()

        let rightBarButtonView = UIView(color: .clear)
        rightBarButtonView.addSubview(viewButton)
        viewButton.anchor(top: rightBarButtonView.topAnchor,
                          leading: rightBarButtonView.leadingAnchor,
                          bottom: rightBarButtonView.bottomAnchor,
                          trailing: rightBarButtonView.trailingAnchor,
                          padding: .init(top: 0, left: 0, bottom: 0, right: 4),
                          size: .init(width: 0,
                                      height: 32))

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    fileprivate func setUpContentView() {

        view.addSubview(collectionView)
        collectionView.anchor(top: view.safeTopAnchor,
                              leading: view.safeLeftAnchor,
                              bottom: view.bottomAnchor,
                              trailing: view.safeRightAnchor,
                              padding: .init(top: 0,
                                             left: 12,
                                             bottom: 0,
                                             right: 12))

        collectionView.dataSource = datasource
        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(DashboardImageCell.self, forCellWithReuseIdentifier: "cellId")
        collectionView.register(DashboardPlainCell.self, forCellWithReuseIdentifier: "cellIdPlain")
    }

    fileprivate func createLayout() -> UICollectionViewLayout {
        switch dashboardType {
        case .image:
            return createLayoutForImageView()
        case .simple:
            return createLayoutForSimpleView()
        default:
            // Should never be here.
            return UICollectionViewLayout()
        }
    }

    private func createLayoutForSimpleView() -> UICollectionViewLayout {
        let widthMultiplier = GlobalHelpers.isDeviceTablet() ?
        (!GlobalHelpers.isDeviceLandscape() ? 0.5 : 0.3333) :
        (GlobalHelpers.isDeviceLandscape() ? 0.5 : 1.0)
        let column: Int = GlobalHelpers.isDeviceTablet() ?
        (!GlobalHelpers.isDeviceLandscape() ? 2 : 3) :
        (GlobalHelpers.isDeviceLandscape() ? 2 : 1)

        let itemEstimatedHeight: CGFloat = 1

        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(widthMultiplier),
                                              heightDimension: .estimated(itemEstimatedHeight))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        // TODO: @Priyonto - Investigate layout issue for iPhone SE 1st and 2nd Gen
        let itemHorizontalSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 6 : 4
        item.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                     leading: itemHorizontalSpacing,
                                                     bottom: 0,
                                                     trailing: UIDevice.isiPhoneSE() ?
                                                     0 : itemHorizontalSpacing)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(itemEstimatedHeight))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = GlobalHelpers.isDeviceTablet() ? 12 : 8
        section.contentInsets = NSDirectionalEdgeInsets(top: 12,
                                                        leading: 0,
                                                        bottom: 12,
                                                        trailing: 0)

        if column == 1 {
            let layout = UICollectionViewCompositionalLayout(section: section)
            self.layout = nil
            return layout
        } else {
            let layout = RuuviSimpleViewCompositionalLayout(section: section,
                                                            columns: column)
            self.layout = layout
            return layout
        }
    }

    private func createLayoutForImageView() -> UICollectionViewLayout {
        let sectionProvider = { (_: Int,
                                 _: NSCollectionLayoutEnvironment)
            -> NSCollectionLayoutSection? in
            let widthMultiplier = GlobalHelpers.isDeviceTablet() ?
                (!GlobalHelpers.isDeviceLandscape() ? 0.5 : 0.3333) :
                (GlobalHelpers.isDeviceLandscape() ? 0.5 : 1.0)

            let itemEstimatedHeight: CGFloat = GlobalHelpers.isDeviceTablet() ? 170 : 144

            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(widthMultiplier),
                                                  heightDimension: .absolute(itemEstimatedHeight))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let itemHorizontalSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 6 : 4
            item.contentInsets = NSDirectionalEdgeInsets(top: 0,
                                                         leading: itemHorizontalSpacing,
                                                         bottom: 0,
                                                         trailing: itemHorizontalSpacing)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .absolute(itemEstimatedHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = GlobalHelpers.isDeviceTablet() ? 12 : 8
            section.contentInsets = NSDirectionalEdgeInsets(top: 12,
                                                            leading: 0,
                                                            bottom: 12,
                                                            trailing: 0)
            return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        let layout = UICollectionViewCompositionalLayout(sectionProvider: sectionProvider,
                                                         configuration: config)
        return layout
    }

    private func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.reloadCollectionView()
        }
    }
}

extension DashboardViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        configureContextMenu(index: indexPath.row)
    }

    func configureContextMenu(index: Int) -> UIContextMenuConfiguration {
        let context = UIContextMenuConfiguration(identifier: nil,
                                                 previewProvider: nil) { [weak self]
            (_) -> UIMenu? in
            self?.highlightedViewModel = self?.viewModels[index]
            return self?.cardContextMenuOption(for: index)
        }
        return context
    }

    func collectionView(_ collectionView: UICollectionView,
                        willEndContextMenuInteraction
                        configuration: UIContextMenuConfiguration,
                        animator: UIContextMenuInteractionAnimating?
    ) {
        highlightedViewModel = nil
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let viewModel = viewModels[indexPath.item]
        output.viewDidTriggerChart(for: viewModel)
    }

    func collectionView(
        _ collectionView: UICollectionView,
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
        perform(#selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation),
                with: nil,
                afterDelay: 0.3)
        if scrollView.isDragging {
            isListRefreshable = false
        }
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        isListRefreshable = true
    }
}

// MARK: - DashboardViewInput
extension DashboardViewController: DashboardViewInput {

    func applyUpdate(to viewModel: CardsViewModel) {
        if let highlightedViewModel = highlightedViewModel,
           (highlightedViewModel.luid.value != nil && highlightedViewModel.luid.value == viewModel.luid.value ||
            highlightedViewModel.mac.value != nil && highlightedViewModel.mac.value == viewModel.mac.value) {
            return
        }

        guard isListRefreshable else {
            return
        }

        var snapshot = datasource.snapshot()
        guard viewModels.count > 0,
              snapshot.numberOfItems > 0,
              viewModels.contains(where: { $0.id.value == viewModel.id.value }),
              let index = snapshot.indexOfItem(viewModel),
              var item = datasource.itemIdentifier(for: IndexPath(item: index,
                                                                  section: 0))
        else {
            return
        }
        item = viewModel
        snapshot.reloadItems([item])
        datasource.apply(snapshot,
                         animatingDifferences: false)
    }

    func localize() {
        // No op.
    }

    func showWebTagAPILimitExceededError() {
        let title = "Cards.WebTagAPILimitExcededError.Alert.title".localized()
        let message = "Cards.WebTagAPILimitExcededError.Alert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = "Cards.BluetoothDisabledAlert.title".localized()
        let message = "Cards.BluetoothDisabledAlert.message".localized()
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "PermissionPresenter.settings".localized(),
                                        style: .default, handler: { _ in
            guard let url = URL(string: userDeclined ?
                                UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
                  UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }))
        alertVC.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showNoSensorsAddedMessage(show: Bool) {
        noSensorView.isHidden = !show
        collectionView.isHidden = show
    }

    func scroll(to index: Int,
                immediately: Bool = false,
                animated: Bool = false) {
        guard index < viewModels.count else { return }
        let indexPath = IndexPath(item: index, section: 0)
        if immediately {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: animated)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let sSelf = self else { return }
                sSelf.collectionView.scrollToItem(at: indexPath,
                                                  at: .centeredVertically,
                                                  animated: animated)
            }
        }
    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        let message = "Cards.KeepConnectionDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogChart(for: viewModel)
        }))
        let keepTitle = "Cards.KeepConnectionDialog.KeepConnection.title".localized()
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionChart(to: viewModel)
        }))
        present(alert, animated: true)
    }

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel, scrollToAlert: Bool) {
        let message = "Cards.KeepConnectionDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogSettings(for: viewModel, scrollToAlert: scrollToAlert)
        }))
        let keepTitle = "Cards.KeepConnectionDialog.KeepConnection.title".localized()
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionSettings(to: viewModel, scrollToAlert: scrollToAlert)
        }))
        present(alert, animated: true)
    }

    func showReverseGeocodingFailed() {
        let message = "Cards.Error.ReverseGeocodingFailed.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    func showAlreadyLoggedInAlert(with email: String) {
        let message = String.localizedStringWithFormat("Cards.Alert.AlreadyLoggedIn.message".localized(),
                                                                 email)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized(), style: .cancel, handler: nil))
        present(alert, animated: true)
    }
}

extension DashboardViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        guard isViewLoaded else {
            return
        }
        reloadCollectionView()
    }
}

extension DashboardViewController: DashboardCellDelegate {
    func didTapAlertButton(for viewModel: CardsViewModel) {
        output.viewDidTriggerSettings(for: viewModel, with: true)
    }
}

extension DashboardViewController: NoSensorViewDelegate {
    func didTapAddSensorButton(sender: NoSensorView) {
        output.viewDidTriggerAddSensors()
    }

    func didTapBuySensorButton(sender: NoSensorView) {
        output.viewDidTriggerBuySensors()
    }
}

extension DashboardViewController {
    fileprivate func updateUI() {
        showNoSensorsAddedMessage(show: viewModels.isEmpty)
        applySnapshot(viewModels)
    }
}
