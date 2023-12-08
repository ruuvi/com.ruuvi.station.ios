// swiftlint:disable file_length
import UIKit
import Humidity
import RuuviOntology
import RuuviLocal
import RuuviService
import RuuviLocalization

class CardsViewController: UIViewController {

    // Configuration
    var output: CardsViewOutput!
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
    var scrollIndex: Int = 0

    private var currentPage: Int = 0 {
        didSet {
            setArrowButtonsVisibility(with: currentPage)
        }
    }
    private static let reuseIdentifier: String = "reuseIdentifier"

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

    func applySnapshot() {
        currentPage = scrollIndex
        collectionView.reloadWithoutAnimation()
        if currentPage < viewModels.count {
            collectionView.scrollTo(index: currentPage)
        }
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
        let buttonImage = RuuviAssets.backButtonImage
        button.setImage(buttonImage, for: .normal)
        button.setImage(buttonImage, for: .highlighted)
        button.imageView?.tintColor = .white
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var alertButton: RuuviCustomButton = {
        let button = RuuviCustomButton(icon: nil)
        button.backgroundColor = .clear
        return button
    }()

    /// This button is used to be able to tap the alert button when
    /// the alert icon is blinking.
    private lazy var alertButtonHidden: UIButton = {
        let button  = UIButton()
        button.backgroundColor = .clear
        button.addTarget(self, action: #selector(alertButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var chartButton: RuuviCustomButton = {
        let button = RuuviCustomButton(icon: RuuviAssets.chartsIcon)
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(chartButtonDidTap)
            )
        )
        return button
    }()

    private lazy var settingsButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: RuuviAssets.settingsIcon,
            iconSize: .init(width: 26, height: 25)
        )
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(settingsButtonDidTap)
            )
        )
        return button
    }()

    // BODY
    private lazy var cardLeftArrowButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "chevron.left")
        )
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(cardLeftArrowButtonDidTap)
            )
        )
        return button
    }()

    private lazy var cardRightArrowButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: UIImage(systemName: "chevron.right")
        )
        button.backgroundColor = .clear
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(cardRightArrowButtonDidTap)
            )
        )
        return button
    }()

    lazy var ruuviTagNameLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.Muli(.extraBold, size: 20)
        return label
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero,
                                  collectionViewLayout: createLayout())
        cv.backgroundColor = .clear
        cv.showsHorizontalScrollIndicator = false
        cv.decelerationRate = .fast
        cv.isPagingEnabled = true
        cv.alwaysBounceVertical = false
        cv.delegate = self
        cv.dataSource = self
        cv.register(CardsLargeImageCell.self,
                    forCellWithReuseIdentifier: Self.reuseIdentifier)
        return cv
    }()

    private var currentVisibleItem: CardsViewModel? {
        didSet {
            bindCurrentVisibleItem()
            updateCardInfo(
                with: currentVisibleItem?.name.value,
                image: currentVisibleItem?.background.value
            )
            updateTopActionButtonVisibility()
        }
    }

    private var isChartsShowing: Bool = false

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
            guard let sSelf = self else { return }
            let flowLayout = sSelf.createLayout()
            sSelf.collectionView.setCollectionViewLayout(
                flowLayout,
                animated: false,
                completion: { _ in
                    guard sSelf.viewModels.count > 0 else { return }
                    if sSelf.currentPage < sSelf.viewModels.count {
                        sSelf.collectionView.scrollTo(index: sSelf.currentPage)
                    }
                }
            )
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
                          padding: .init(top: 0, left: -12, bottom: 0, right: 0),
                          size: .init(width: 40, height: 40))

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(top: nil,
                             leading: backButton.trailingAnchor,
                             bottom: nil,
                             trailing: leftBarButtonView.trailingAnchor,
                             padding: .init(top: 0, left: 12, bottom: 0, right: 0),
                             size: .init(width: 110, height: 22))
        ruuviLogoView.centerYInSuperview()

        let rightBarButtonView = UIView(color: .clear)
        // Right action buttons
        rightBarButtonView.addSubview(alertButton)
        alertButton.anchor(top: rightBarButtonView.topAnchor,
                           leading: rightBarButtonView.leadingAnchor,
                           bottom: rightBarButtonView.bottomAnchor,
                           trailing: nil)
        alertButton.centerYInSuperview()

        rightBarButtonView.addSubview(alertButtonHidden)
        alertButtonHidden.match(view: alertButton)

        rightBarButtonView.addSubview(chartButton)
        chartButton.anchor(top: nil,
                           leading: alertButton.trailingAnchor,
                           bottom: nil,
                           trailing: nil)
        chartButton.centerYInSuperview()

        rightBarButtonView.addSubview(settingsButton)
        settingsButton.anchor(top: nil,
                              leading: chartButton.trailingAnchor,
                              bottom: nil,
                              trailing: rightBarButtonView.trailingAnchor,
                              padding: .init(top: 0, left: 0, bottom: 0, right: -14))
        settingsButton.centerYInSuperview()

        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    fileprivate func setUpContentView() {
        let swipeToolbarView  = UIView(color: .clear)
        // Arrow buttons should stay above of collection view
        swipeToolbarView.addSubview(cardLeftArrowButton)
        cardLeftArrowButton.anchor(
            top: swipeToolbarView.topAnchor,
            leading: swipeToolbarView.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 6, left: 4, bottom: 0, right: 0)
        )

        swipeToolbarView.addSubview(cardRightArrowButton)
        cardRightArrowButton.anchor(
            top: swipeToolbarView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: swipeToolbarView.trailingAnchor,
            padding: .init(top: 4, left: 0, bottom: 0, right: 4)
        )

        swipeToolbarView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: swipeToolbarView.topAnchor,
            leading: cardLeftArrowButton.trailingAnchor,
            bottom: swipeToolbarView.bottomAnchor,
            trailing: cardRightArrowButton.leadingAnchor,
            padding: .init(top: 8, left: 8, bottom: 6, right: 8)
        )

        view.addSubview(swipeToolbarView)
        swipeToolbarView.anchor(top: view.safeTopAnchor,
                                leading: view.safeLeftAnchor,
                                bottom: nil,
                                trailing: view.safeRightAnchor)

        view.addSubview(collectionView)
        collectionView.anchor(top: swipeToolbarView.bottomAnchor,
                              leading: view.safeLeftAnchor,
                              bottom: view.safeBottomAnchor,
                              trailing: view.safeRightAnchor)
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
}

extension CardsViewController: UICollectionViewDelegate {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let xPoint = scrollView.contentOffset.x + scrollView.frame.size.width / 2
        let yPoint = scrollView.frame.size.height / 2
        let center = CGPoint(x: xPoint, y: yPoint)
        if let currentIndexPath = collectionView.indexPathForItem(at: center) {
            performPostScrollActions(with: currentIndexPath.row)
        }
    }
}

extension CardsViewController: UICollectionViewDataSource {
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

extension CardsViewController {
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
        output.viewDidTriggerSettings(for: viewModel)
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
        view.insertSubview(module.view, aboveSubview: collectionView)
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
        output.viewDidTriggerSettings(for: viewModel)
    }

    @objc fileprivate func cardLeftArrowButtonDidTap() {
        guard viewModels.count > 0 else { return }
        let scrollToPageIndex = currentPage - 1
        if scrollToPageIndex >= 0 && scrollToPageIndex < viewModels.count {
            performPostScrollActions(with: scrollToPageIndex, scroll: true)
        }
    }

    @objc fileprivate func cardRightArrowButtonDidTap() {
        guard viewModels.count > 0 else { return }
        let scrollToPageIndex = currentPage + 1
        if scrollToPageIndex >= 0 && scrollToPageIndex < viewModels.count {
            performPostScrollActions(with: scrollToPageIndex, scroll: true)
        }
    }
}

// MARK: - CardsViewInput
extension CardsViewController: CardsViewInput {

    func viewShouldDismiss() {
        output.viewShouldDismiss()
    }

    func applyUpdate(to viewModel: CardsViewModel) {
        if let index = viewModels.firstIndex(where: { vm in
            vm.luid.value != nil && vm.luid.value == viewModel.luid.value ||
            vm.mac.value != nil && vm.mac.value == viewModel.mac.value
        }) {
            let indexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView
                .cellForItem(at: indexPath) as? CardsLargeImageCell {
                cell.configure(
                    with: viewModel, measurementService: measurementService
                )
                restartAnimations()
                updateTopActionButtonVisibility()
            }
        }
    }

    func changeCardBackground(of viewModel: CardsViewModel,
                              to image: UIImage?) {
        if viewModel == currentVisibleItem {
            updateCardInfo(with: viewModel.name.value, image: image)
        }
    }

    func localize() {
        // No op.
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = RuuviLocalization.Cards.BluetoothDisabledAlert.title
        let message = RuuviLocalization.Cards.BluetoothDisabledAlert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.PermissionPresenter.settings,
                                        style: .default, handler: { _ in
            guard let url = URL(string: userDeclined ?
                                UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
                  UIApplication.shared.canOpenURL(url) else {
                return
            }
            UIApplication.shared.open(url)
        }))
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func scroll(to index: Int) {
        guard viewModels.count > 0,
              index < viewModels.count else {
            return
        }
        let viewModel = viewModels[index]
        currentVisibleItem = viewModel
        currentPage = index
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(100)) { [weak self] in
            guard let sSelf = self else { return }
            sSelf.collectionView.scrollTo(index: index, animated: false)
            sSelf.output.viewDidTriggerFirmwareUpdateDialog(for: viewModel)
        }

        restartAnimations()
    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogChart(for: viewModel)
        }))
        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionChart(to: viewModel)
        }))
        present(alert, animated: true)
    }

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        let message = RuuviLocalization.Cards.KeepConnectionDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissKeepConnectionDialogSettings(for: viewModel)
        }))
        let keepTitle = RuuviLocalization.Cards.KeepConnectionDialog.KeepConnection.title
        alert.addAction(UIAlertAction(title: keepTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmToKeepConnectionSettings(to: viewModel)
        }))
        present(alert, animated: true)
    }

    func showFirmwareUpdateDialog(for viewModel: CardsViewModel) {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidIgnoreFirmwareUpdateDialog(for: viewModel)
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate(for: viewModel)
        }))
        present(alert, animated: true)
    }

    func showFirmwareDismissConfirmationUpdateDialog(for viewModel: CardsViewModel) {
        let message = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CancelConfirmation.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        let dismissTitle = RuuviLocalization.Cards.KeepConnectionDialog.Dismiss.title
        alert.addAction(UIAlertAction(title: dismissTitle, style: .cancel, handler: { [weak self] _ in
            self?.output.viewDidDismissFirmwareUpdateDialog(for: viewModel)
        }))
        let checkForUpdateTitle = RuuviLocalization.Cards.LegacyFirmwareUpdateDialog.CheckForUpdate.title
        alert.addAction(UIAlertAction(title: checkForUpdateTitle, style: .default, handler: { [weak self] _ in
            self?.output.viewDidConfirmFirmwareUpdate(for: viewModel)
        }))
        present(alert, animated: true)
    }

    func showReverseGeocodingFailed() {
        let message = RuuviLocalization.Cards.Error.ReverseGeocodingFailed.message
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    func showAlreadyLoggedInAlert(with email: String) {
        let message = RuuviLocalization.Cards.Alert.AlreadyLoggedIn.message(email)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
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
        applySnapshot()

        if scrollIndex < viewModels.count {
            let item = viewModels[scrollIndex]
            currentVisibleItem = item
        }
    }

    private func bindCurrentVisibleItem() {
        guard let currentVisibleItem = currentVisibleItem else {
            return
        }

        view.bind(currentVisibleItem.name) { [weak self] (_, name) in
            self?.updateCardInfo(with: name, image: currentVisibleItem.background.value)
        }

        view.bind(currentVisibleItem.temperatureAlertMutedTill) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.relativeHumidityAlertMutedTill) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.pressureAlertMutedTill) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.signalAlertMutedTill) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.movementAlertMutedTill) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.connectionAlertMutedTill) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.alertState) { [weak self] (_, _) in
            self?.restartAnimations()
        }

        view.bind(currentVisibleItem.isChartAvailable) { [weak self] (_, _) in
            self?.updateTopActionButtonVisibility()
        }

        view.bind(currentVisibleItem.isAlertAvailable) { [weak self] (_, _) in
            self?.updateTopActionButtonVisibility()
        }

        view.bind(currentVisibleItem.isConnected) { [weak self] (_, _) in
            self?.updateTopActionButtonVisibility()
        }
    }
}

extension CardsViewController {
    private func updateCardInfo(with name: String?, image: UIImage?) {
        ruuviTagNameLabel.text = name
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
        }
    }

    private func setArrowButtonsVisibility(hidden: Bool, animated: Bool) {
        if hidden {
            cardLeftArrowButton.fadeOut(animated: animated)
            cardRightArrowButton.fadeOut(animated: animated)
        } else {
            cardLeftArrowButton.fadeIn(animated: animated)
            cardRightArrowButton.fadeIn(animated: animated)
        }
    }

    private func setArrowButtonsVisibility(with index: Int) {
        if index == 0 {
            cardLeftArrowButton.fadeOut()
        } else {
            cardLeftArrowButton.fadeIn()
        }

        if index == viewModels.count - 1 {
            cardRightArrowButton.fadeOut()
        } else {
            cardRightArrowButton.fadeIn()
        }
    }

    private func performPostScrollActions(with index: Int, scroll: Bool = false) {
        let currentItem = viewModels[index]
        if isChartsShowing {
            output.viewDidTriggerNavigateChart(to: currentItem)
        } else {
            currentPage = index
            self.currentVisibleItem = currentItem
            restartAnimations()
            output.viewDidScroll(to: currentItem)
            output.viewDidTriggerFirmwareUpdateDialog(for: currentItem)

            if scroll {
                collectionView.scrollTo(index: index, animated: true)
            }
        }
    }
}
