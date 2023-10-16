// swiftlint:disable file_length
import UIKit
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService

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

    var dashboardTapActionType: DashboardTapActionType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
        }
    }

    var userSignedInOnce: Bool = false {
        didSet {
            noSensorView.userSignedInOnce = userSignedInOnce
        }
    }

    private func cell(collectionView: UICollectionView,
                      indexPath: IndexPath,
                      viewModel: CardsViewModel) -> UICollectionViewCell? {
        switch dashboardType {
        case .image:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cellId",
                for: indexPath
            ) as? DashboardImageCell
            cell?.configure(with: viewModel, measurementService: measurementService)
            cell?.restartAlertAnimation(for: viewModel)
            cell?.delegate = self
            cell?.moreButton.menu = cardContextMenuOption(for: indexPath.item)
            return cell
        case .simple:
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: "cellIdPlain",
                for: indexPath
            ) as? DashboardPlainCell
            cell?.configure(with: viewModel, measurementService: measurementService)
            cell?.restartAlertAnimation(for: viewModel)
            cell?.delegate = self
            cell?.moreButton.menu = cardContextMenuOption(for: indexPath.item)
            return cell
        case .none:
            return nil
        }
    }

    // UI
    private lazy var noSensorView: NoSensorView = {
       let view = NoSensorView()
        view.backgroundColor = RuuviColor.dashboardCardBGColor
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.delegate = self
        view.userSignedInOnce = userSignedInOnce
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
                               icon: RuuviAssets.dropDownArrowImage,
                               iconTintColor: RuuviColor.logoTintColor,
                               iconSize: .init(width: 14, height: 14),
                               preccedingIcon: false)

    // BODY
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )
        cv.backgroundColor = .clear
        cv.showsVerticalScrollIndicator = false
        cv.delegate = self
        cv.dataSource = self
        cv.alwaysBounceVertical = true
        cv.refreshControl = refresher
        return cv
    }()

    private lazy var refresher: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = RuuviColor.ruuviTintColor
        rc.layer.zPosition = -1
        rc.alpha = 0
        rc.addTarget(self, action: #selector(didPullToRefresh), for: .valueChanged)
        return rc
    }()
    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32

    private var appDidBecomeActiveToken: NSObjectProtocol?

    private var isListRefreshable: Bool = true
    private var isRefreshing: Bool = false
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
        configureRestartAnimationsOnAppDidBecomeActive()
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
            self?.collectionView.reloadWithoutAnimation()
        }
    }

    @objc fileprivate func didPullToRefresh() {
        guard !isRefreshing else {
          refresher.endRefreshing()
          return
        }
        refresher.fadeIn()
        isRefreshing = true
        output.viewDidTriggerPullToRefresh()
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1), execute: { [weak self] in
            self?.refresher.endRefreshing()
            self?.isRefreshing = false
            self?.refresher.fadeOut()
        })
    }
}

extension DashboardViewController {
    private func viewToggleMenuOptions() -> UIMenu {
        // Card Type
        let imageViewTypeAction = UIAction(title: "image_cards".localized()) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .image)
            self?.reloadCollectionView(redrawLayout: true)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let simpleViewTypeAction = UIAction(title: "simple_cards".localized()) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .simple)
            self?.reloadCollectionView(redrawLayout: true)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        simpleViewTypeAction.state = dashboardType == .simple ? .on : .off
        imageViewTypeAction.state = dashboardType == .image ? .on : .off

        let cardTypeMenu = UIMenu(title: "card_type".localized(),
                                  options: .displayInline,
                                  children: [
            imageViewTypeAction, simpleViewTypeAction
        ])

        // Card action
        let openSensorViewAction = UIAction(title: "open_sensor_view".localized()) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .card)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let openHistoryViewAction = UIAction(title: "open_history_view".localized()) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .chart)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        openSensorViewAction.state = dashboardTapActionType == .card ? .on : .off
        openHistoryViewAction.state = dashboardTapActionType == .chart ? .on : .off

        let cardActionMenu = UIMenu(title: "card_action".localized(),
                                    options: .displayInline,
                                    children: [
            openSensorViewAction, openHistoryViewAction
        ])

        return UIMenu(
            title: "",
            children: [
                cardTypeMenu, cardActionMenu
            ]
        )
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
                self?.output.viewDidTriggerSettings(for: viewModel)
            }
        }

        let changeBackgroundAction = UIAction(title: "change_background".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChangeBackground(for: viewModel)
            }
        }

        let renameAction = UIAction(title: "rename".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerRename(for: viewModel)
            }
        }

        let shareSensorAction = UIAction(title: "TagSettings.ShareButton".localized()) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerShare(for: viewModel)
            }
        }

        var contextMenuActions: [UIAction] = [
          fullImageViewAction,
          historyViewAction,
          settingsAction,
          changeBackgroundAction,
          renameAction
        ]

        let viewModel = viewModels[index]
        if let canShare = viewModel.canShareTag.value,
           canShare {
          contextMenuActions.append(shareSensorAction)
        }

        return UIMenu(title: "", children: contextMenuActions)
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
                              padding: .init(top: 12,
                                             left: 12,
                                             bottom: 0,
                                             right: 12))

        collectionView.showsVerticalScrollIndicator = false
        collectionView.register(DashboardImageCell.self, forCellWithReuseIdentifier: "cellId")
        collectionView.register(DashboardPlainCell.self, forCellWithReuseIdentifier: "cellIdPlain")
    }

    // swiftlint:disable:next function_body_length
    fileprivate func createLayout() -> UICollectionViewLayout {
        var itemEstimatedHeight: CGFloat = 144
        switch dashboardType {
        case .image:
            itemEstimatedHeight = GlobalHelpers.isDeviceTablet() ? 170 : 144
        case .simple:
            itemEstimatedHeight = GlobalHelpers.isDeviceTablet() ? 110 : 90
        default:
            break
        }

        let sectionProvider = { (_: Int,
                                 _: NSCollectionLayoutEnvironment)
            -> NSCollectionLayoutSection? in
            let widthMultiplier = GlobalHelpers.isDeviceTablet() ?
                (!GlobalHelpers.isDeviceLandscape() ? 0.5 : 0.3333) :
                (GlobalHelpers.isDeviceLandscape() ? 0.5 : 1.0)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(widthMultiplier),
                heightDimension: .absolute(itemEstimatedHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let itemHorizontalSpacing: CGFloat = GlobalHelpers.isDeviceTablet() ? 6 : 4
            item.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: itemHorizontalSpacing,
                bottom: 0,
                trailing: itemHorizontalSpacing
            )

            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(itemEstimatedHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize, subitems: [item]
            )

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = GlobalHelpers.isDeviceTablet() ? 12 : 8
            section.contentInsets = NSDirectionalEdgeInsets(
                top: 0,
                leading: 0,
                bottom: 12,
                trailing: 0
            )
            return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .vertical
        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider,
            configuration: config
        )
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

extension DashboardViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return viewModels.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = cell(
            collectionView: collectionView,
            indexPath: indexPath,
            viewModel: viewModels[indexPath.item]
        ) else {
            fatalError()
        }
        return cell
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
        output.viewDidTriggerDashboardCard(for: viewModel)
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
            refresher.fadeIn()
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

        if let index = viewModels.firstIndex(where: { vm in
            vm.luid.value != nil && vm.luid.value == viewModel.luid.value ||
            vm.mac.value != nil && vm.mac.value == viewModel.mac.value
        }) {
            let indexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView
                .cellForItem(at: indexPath) as? DashboardImageCell {
                cell.configure(
                    with: viewModel, measurementService: measurementService
                )
                cell.restartAlertAnimation(for: viewModel)
            } else if let cell = collectionView
                .cellForItem(at: indexPath) as? DashboardPlainCell {
                cell.configure(
                    with: viewModel, measurementService: measurementService
                )
                cell.restartAlertAnimation(for: viewModel)
            }
        }
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
        noSensorView.updateView(userSignInOnce: userSignedInOnce)
        noSensorView.isHidden = !show
        collectionView.isHidden = show
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

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        let message = "Cards.KeepConnectionDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogSettings(for: viewModel)
        }))
        let keepTitle = "Cards.KeepConnectionDialog.KeepConnection.title".localized()
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionSettings(to: viewModel)
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

    func showSensorNameRenameDialog(for viewModel: CardsViewModel) {
        let alert = UIAlertController(title: "TagSettings.tagNameTitleLabel.text".localized(),
                                      message: "TagSettings.tagNameTitleLabel.rename.text".localized(),
                                      preferredStyle: .alert)
        alert.addTextField { [weak self] alertTextField in
            guard let self = self else { return }
            alertTextField.delegate = self
            alertTextField.text = viewModel.name.value
            self.tagNameTextField = alertTextField
        }
        let action = UIAlertAction(title: "OK".localized(), style: .default) { [weak self] _ in
            guard let self = self else { return }
            guard let name = self.tagNameTextField.text, !name.isEmpty else { return }
            self.output.viewDidRenameTag(to: name, viewModel: viewModel)
        }
        let cancelAction = UIAlertAction(title: "Cancel".localized(), style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
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
        output.viewDidTriggerSettings(for: viewModel)
    }
}

extension DashboardViewController: NoSensorViewDelegate {
    func didTapSignInButton(sender: NoSensorView) {
        output.viewDidTriggerSignIn()
    }

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
        collectionView.reloadWithoutAnimation()
    }
}

    // MARK: - UITextFieldDelegate
extension DashboardViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn
                   range: NSRange,
                   replacementString string: String) -> Bool {
        guard let text = textField.text else {
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
