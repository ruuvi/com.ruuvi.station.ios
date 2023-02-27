// swiftlint:disable file_length
import UIKit
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService
import GestureInstructions

enum CardsSection: CaseIterable {
    case main
}

typealias CardsSnapshot = NSDiffableDataSourceSnapshot<CardsSection, CardsViewModel>
typealias CardsDataSource = UICollectionViewDiffableDataSource<CardsSection, CardsViewModel>

class CardsViewController: UIViewController {

    // Configuration
    var output: CardsViewOutput!
    var measurementService: RuuviServiceMeasurement! {
        didSet {
            measurementService?.add(self)
        }
    }

    var viewModels: [CardsViewModel] = []
    var scrollIndex: Int = 0 {
        didSet {
            updateUI()
        }
    }

    var currentPage: Int = 0

    private lazy var datasource = makeDatasource()
    private static let reuseIdentifier: String = "reuseIdentifier"
    // MARK: - Datasource
    private func makeDatasource() -> CardsDataSource {
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
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Self.reuseIdentifier,
            for: indexPath
        ) as? CardsLargeImageCell
        cell?.configure(with: viewModel, measurementService: measurementService)
        return cell
    }

    func applySnapshot(_ items: [CardsViewModel]) {
        var snapshot = CardsSnapshot()
        snapshot.appendSections([.main])
        snapshot.appendItems(items, toSection: .main)
        currentPage = scrollIndex
        datasource.apply(snapshot,
                         animatingDifferences: true,
                         completion: nil)
    }

    private var appDidBecomeActiveToken: NSObjectProtocol?

    // Base
    private lazy var cardBackgroundView = CardsBackgroundView()
    private lazy var chartViewBackground = UIView(color: RuuviColor.ruuviGraphBGColor)

    // Header View
    // Ruuvi Logo
    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(image: UIImage(named: "ruuvi_logo_"),
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        return iv
    }()

    // Action Buttons
    private lazy var backButton: UIButton = {
        let button  = UIButton()
        button.tintColor = .white
        let buttonImage = UIImage(named: "chevron_back")
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .white
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    // TODO: Make alert and chart button hidden/visible based on connected status of tag.
    private lazy var alertButton: UIImageView = {
        let iv = UIImageView(image: nil,
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        return iv
    }()

    /// This button is used to be able to tap the alert button when
    /// the alert icon is blinking.
    private lazy var alertButtonHidden: UIButton = {
        let button  = UIButton()
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(alertButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var chartButton: UIImageView = {
        let iv = UIImageView(image: RuuviAssets.chartsIcon,
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        iv.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                       action: #selector(chartButtonDidTap)))
        return iv
    }()

    private lazy var settingsButton: UIImageView = {
        let iv = UIImageView(image: RuuviAssets.settingsIcon,
                             contentMode: .scaleAspectFit)
        iv.tintColor = .white
        iv.addGestureRecognizer(UITapGestureRecognizer(target: self,
                                                       action: #selector(settingsButtonDidTap)))
        return iv
    }()

    // BODY
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero,
                                  collectionViewLayout: createLayout())
        cv.backgroundColor = .clear
        cv.delegate = self
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.isPagingEnabled = true
        cv.alwaysBounceVertical = false
        cv.register(CardsLargeImageCell.self,
                    forCellWithReuseIdentifier: Self.reuseIdentifier)
        return cv
    }()

    private var currentVisibleItem: CardsViewModel? {
        didSet {
            updateCardBackgroundImage(with: currentVisibleItem?.background.value)
            updateTopActionButtonVisibility()
        }
    }

    private var isChartsShowing: Bool = false
    private var isCardRefreshable: Bool = true

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
}

// MARK: - View lifecycle
extension CardsViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        configureGestureViews()
        setupLocalization()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.makeTransparent()
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.resetStyleToDefault()
        output.viewWillDisappear()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restartAnimations()
        output.viewDidAppear()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Scroll to current Item after the orientation change.
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.collectionView.collectionViewLayout.invalidateLayout()
            let indexPath = IndexPath(item: self?.currentPage ?? 0,
                                      section: 0)
            self?.collectionView.scrollToItem(at: indexPath,
                                        at: .centeredHorizontally,
                                        animated: false)
        })
    }
}

extension CardsViewController {
    fileprivate func setUpUI() {
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
    }

    fileprivate func setUpBaseView() {
        view.backgroundColor = RuuviColor.ruuviPrimary

        view.addSubview(cardBackgroundView)
        cardBackgroundView.fillSuperview()

        view.addSubview(chartViewBackground)
        chartViewBackground.fillSuperview()
        chartViewBackground.alpha = 0
    }

    fileprivate func setUpHeaderView() {
        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(backButton)
        backButton.anchor(top: leftBarButtonView.topAnchor,
                          leading: leftBarButtonView.leadingAnchor,
                          bottom: leftBarButtonView.bottomAnchor,
                          trailing: nil,
                          padding: .init(top: 0, left: -8, bottom: 0, right: 0),
                          size: .init(width: 32, height: 32))

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(top: nil,
                             leading: backButton.trailingAnchor,
                             bottom: nil,
                             trailing: leftBarButtonView.trailingAnchor,
                             padding: .init(top: 0, left: 16, bottom: 0, right: 0),
                             size: .init(width: 110, height: 22))
        ruuviLogoView.centerYInSuperview()

        let rightBarButtonView = UIView(color: .clear)
        // Right action buttons
        rightBarButtonView.addSubview(alertButton)
        alertButton.anchor(top: rightBarButtonView.topAnchor,
                           leading: rightBarButtonView.leadingAnchor,
                           bottom: rightBarButtonView.bottomAnchor,
                           trailing: nil,
                           size: .init(width: 20, height: 20))
        alertButton.centerYInSuperview()

        rightBarButtonView.addSubview(alertButtonHidden)
        alertButtonHidden.match(view: alertButton)

        rightBarButtonView.addSubview(chartButton)
        chartButton.anchor(top: nil,
                           leading: alertButton.trailingAnchor,
                           bottom: nil,
                           trailing: nil,
                           padding: .init(top: 0, left: 22, bottom: 0, right: 0),
                           size: .init(width: 20, height: 20))
        chartButton.centerYInSuperview()

        rightBarButtonView.addSubview(settingsButton)
        settingsButton.anchor(top: nil,
                              leading: chartButton.trailingAnchor,
                              bottom: nil,
                              trailing: rightBarButtonView.trailingAnchor,
                              padding: .init(top: 0, left: 16, bottom: 0, right: 0),
                              size: .init(width: 26, height: 25))
        settingsButton.centerYInSuperview()

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    fileprivate func setUpContentView() {
        view.addSubview(collectionView)
        collectionView.anchor(top: view.safeTopAnchor,
                              leading: view.safeLeftAnchor,
                              bottom: view.safeBottomAnchor,
                              trailing: view.safeRightAnchor)

        collectionView.dataSource = datasource
    }

    fileprivate func createLayout() -> UICollectionViewLayout {
        let sectionProvider = { (_: Int,
                                 _: NSCollectionLayoutEnvironment)
            -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            item.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .fractionalHeight(1.0))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

            let section = NSCollectionLayoutSection(group: group)
            return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.scrollDirection = .horizontal
        let layout = UICollectionViewCompositionalLayout(sectionProvider: sectionProvider,
                                                         configuration: config)
        return layout
    }

    private func configureGestureViews() {
        configureGestureInstructor()
        configureRestartAnimationsOnAppDidBecomeActive()
    }

    private func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(forName: UIApplication.didBecomeActiveNotification,
                         object: nil,
                         queue: .main) { [weak self] _ in
                self?.restartAnimations()
        }
    }

    private func configureGestureInstructor() {
        GestureInstructor.appearance.tapImage = UIImage(named: "gesture-assistant-hand")
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let xPoint = scrollView.contentOffset.x + scrollView.frame.size.width / 2
        let yPoint = scrollView.frame.size.height / 2
        let center = CGPoint(x: xPoint, y: yPoint)
        if let currentIndexPath = collectionView.indexPathForItem(at: center),
           let currentVisibleItem = datasource.itemIdentifier(for: currentIndexPath) {
            currentPage = currentIndexPath.row
            self.currentVisibleItem = currentVisibleItem
            restartAnimations()
            output.viewDidScroll(to: currentVisibleItem)
            output.viewDidTriggerFirmwareUpdateDialog(for: currentVisibleItem)
        }
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        perform(#selector(UIScrollViewDelegate.scrollViewDidEndScrollingAnimation),
                with: nil,
                afterDelay: 0.3)
        isCardRefreshable = false
    }

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        isCardRefreshable = true
    }
}

extension CardsViewController: UICollectionViewDelegate {
    @objc fileprivate func backButtonDidTap() {
        // TODO: Handle the case when chart visible and sync ongoing.
        if isChartsShowing {
            guard let viewModel = currentVisibleItem else {
                return
            }
            output.viewDidTriggerDismissChart(for: viewModel,
                                              dismissParent: true)
        } else {
            output.viewShouldDismiss()
        }
    }

    @objc fileprivate func alertButtonDidTap() {
        guard let viewModel = currentVisibleItem else {
            return
        }
        output.viewDidTriggerSettings(for: viewModel, with: true)
    }

    @objc fileprivate func chartButtonDidTap() {
        guard let viewModel = currentVisibleItem else {
            return
        }

        if isChartsShowing {
            output.viewDidTriggerDismissChart(for: viewModel,
                                              dismissParent: false)
        } else {
            output.viewDidTriggerShowChart(for: viewModel)
        }
    }

    func showChart(module: UIViewController) {
        chartButton.image = RuuviAssets.cardsIcon
        chartViewBackground.alpha = 1
        collectionView.isHidden = true
        module.willMove(toParent: self)
        addChild(module)
        view.addSubview(module.view)
        module.view.match(view: collectionView)
        module.didMove(toParent: self)
        isChartsShowing = true
    }

    func dismissChart() {
        chartButton.image = RuuviAssets.chartsIcon
        chartViewBackground.alpha = 0
        children.forEach({
            $0.willMove(toParent: nil)
            $0.view.removeFromSuperview()
            $0.removeFromParent()
        })
        isChartsShowing = false
        collectionView.isHidden = false
    }

    @objc fileprivate func settingsButtonDidTap() {
        guard let viewModel = currentVisibleItem else {
            return
        }
        navigationController?.setNavigationBarHidden(false, animated: false)
        output.viewDidTriggerSettings(for: viewModel, with: false)
    }
}

// MARK: - CardsViewInput
extension CardsViewController: CardsViewInput {

    func viewShouldDismiss() {
        _ = navigationController?.popToRootViewController(animated: true)
    }

    func applyUpdate(to viewModel: CardsViewModel) {
        guard isCardRefreshable else { return }
        var snapshot = datasource.snapshot()
        if let index = snapshot.indexOfItem(viewModel),
           var item = datasource.itemIdentifier(for: IndexPath(item: index,
                                                               section: 0)) {
            if viewModel == currentVisibleItem {
                item = viewModel
                restartAnimations()
                updateTopActionButtonVisibility()
                snapshot.reloadItems([item])
                datasource.apply(snapshot,
                                 animatingDifferences: false,
                                 completion: nil)
            }
        }
    }

    func changeCardBackground(of viewModel: CardsViewModel,
                              to image: UIImage?) {
        if viewModel == currentVisibleItem {
            updateCardBackgroundImage(with: image)
        }
    }

    func localize() {

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

    func showSwipeLeftRightHint() {
        gestureInstructor.show(.swipeRight, after: 0.1)
    }

    func scroll(to index: Int,
                immediately: Bool = false,
                animated: Bool = false) {
        guard index < viewModels.count, index < datasource.snapshot().numberOfItems else {
            return
        }
        let viewModel = viewModels[index]
        let indexPath = IndexPath(item: index, section: 0)
        if immediately {
            collectionView.scrollToItem(at: indexPath,
                                        at: .centeredHorizontally,
                                        animated: animated)
            output.viewDidTriggerFirmwareUpdateDialog(for: viewModel)
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
                guard let sSelf = self else { return }
                sSelf.collectionView.scrollToItem(at: indexPath,
                                                  at: .centeredHorizontally,
                                                  animated: animated)
                sSelf.output.viewDidTriggerFirmwareUpdateDialog(for: viewModel)
            }
        }

        restartAnimations()
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

    func showFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        let message = "Cards.LegacyFirmwareUpdateDialog.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog(for: viewModel)
        }))
        let checkForUpdateTitle = "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title".localized()
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate(for: viewModel)
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel) {
        let message = "Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message".localized()
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = "Cards.KeepConnectionDialog.Dismiss.title".localized()
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissFirmwareUpdateDialog(for: viewModel)
        }))
        let checkForUpdateTitle = "Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title".localized()
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate(for: viewModel)
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

extension CardsViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        guard isViewLoaded,
                let viewModel = currentVisibleItem else {
            return
        }
        applyUpdate(to: viewModel)
    }
}

extension CardsViewController {
    fileprivate func updateUI() {
        applySnapshot(viewModels)

        if scrollIndex < viewModels.count {
            let item = viewModels[scrollIndex]
            currentVisibleItem = item
        }
    }
}

extension CardsViewController {
    private func updateCardBackgroundImage(with image: UIImage?) {
        cardBackgroundView.setBackgroundImage(with: image)
    }

    private func restartAnimations() {
        let mutedTills = [
            currentVisibleItem?.temperatureAlertMutedTill.value,
            currentVisibleItem?.relativeHumidityAlertMutedTill.value,
            currentVisibleItem?.pressureAlertMutedTill.value,
            currentVisibleItem?.signalAlertMutedTill.value,
            currentVisibleItem?.movementAlertMutedTill.value,
            currentVisibleItem?.connectionAlertMutedTill.value
        ]

        if mutedTills.first(where: { $0 != nil }) != nil {
            alertButton.image = RuuviAssets.alertOffImage
            removeAlertAnimations(alpha: 0.5)
            return
        }

        if let state = currentVisibleItem?.alertState.value {
            switch state {
            case .empty:
                alertButton.image = RuuviAssets.alertOffImage
                removeAlertAnimations(alpha: 0.5)
            case .registered:
                alertButton.image = RuuviAssets.alertOnImage
                removeAlertAnimations()
            case .firing:
                alertButton.alpha = 1.0
                alertButton.image = RuuviAssets.alertActiveImage
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    UIView.animate(withDuration: 0.5,
                                   delay: 0,
                                   options: [.repeat,
                                             .autoreverse],
                                   animations: { [weak self] in
                        self?.alertButton.alpha = 0.0
                    })
                })
            }
        } else {
            alertButton.image = nil
            removeAlertAnimations()
        }
    }

    func removeAlertAnimations(alpha: Double = 1) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1,
                                      execute: { [weak self] in
            self?.alertButton.layer.removeAllAnimations()
            self?.alertButton.alpha = alpha
        })
    }

    private func updateTopActionButtonVisibility() {
        guard let viewModel = currentVisibleItem else {
            return
        }

        if let isChartAvaiable = viewModel.isChartAvailable.value {
            chartButton.isHidden = !isChartAvaiable
        } else {
            chartButton.isHidden = true
        }

        let type = viewModel.type
        switch type {
        case .ruuvi:
            if let isAlertAvailable = viewModel.isAlertAvailable.value {
                alertButton.isHidden = !isAlertAvailable
                alertButtonHidden.isUserInteractionEnabled = isAlertAvailable
            } else {
                alertButton.isHidden = !viewModel.isConnected.value.bound
                alertButtonHidden.isUserInteractionEnabled = viewModel.isConnected.value.bound
            }
        case .web:
            // Hide alert bell for virtual tags
            alertButton.isHidden = true
            alertButtonHidden.isUserInteractionEnabled = false
        }
    }
}
