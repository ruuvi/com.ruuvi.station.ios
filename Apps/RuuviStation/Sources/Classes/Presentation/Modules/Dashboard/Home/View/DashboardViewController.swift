
import RuuviLocal
import RuuviLocalization
import RuuviOntology
import RuuviService
// swiftlint:disable file_length
import UIKit
import Combine
import SwiftUI

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

    var viewModels: [CardsViewModel] {
        get { state.items }
        set { state.updateItems(newValue) }
    }

    var isRefreshing: Bool {
        get { state.isRefreshing }
        set {
            state.updateRefreshState(newValue)
            if isRefreshing {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    var dashboardType: DashboardType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
            state.dashboardViewType = dashboardType
        }
    }

    var dashboardTapActionType: DashboardTapActionType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
        }
    }

    var dashboardSortingType: DashboardSortingType! {
        didSet {
            viewButton.updateMenu(with: viewToggleMenuOptions())
        }
    }

    var shouldShowSignInBanner: Bool = false {
        didSet {
            showNoSignInBannerIfNeeded()
        }
    }

    // UI
    private lazy var noSensorView: NoSensorView = {
        let view = NoSensorView()
        view.backgroundColor = RuuviColor.dashboardCardBG.color
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        view.delegate = self
        return view
    }()

    // Header View
    // Ruuvi Logo
    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.ruuviLogo.image.withRenderingMode(.alwaysTemplate),
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.logoTintColor.color
        return iv
    }()

    // Action Buttons

    private lazy var menuButton: RuuviCustomButton = {
        let button = RuuviCustomButton(
            icon: RuuviAsset.baselineMenuWhite48pt.image,
            tintColor: RuuviColor.menuTintColor.color,
            iconSize: .init(width: 36, height: 36),
            leadingPadding: 6,
            trailingPadding: 6
        )
        button.addGestureRecognizer(
            UITapGestureRecognizer(
                target: self,
                action: #selector(handleMenuButtonTap)
            )
        )
        return button
    }()

    private lazy var viewButton: RuuviContextMenuButton =
        .init(
            menu: viewToggleMenuOptions(),
            titleColor: RuuviColor.dashboardIndicator.color,
            title: RuuviLocalization.view,
            icon: RuuviAsset.arrowDropDown.image,
            iconTintColor: RuuviColor.logoTintColor.color,
            iconSize: .init(width: 14, height: 14),
            preccedingIcon: false
        )

    // BODY
    private lazy var dashboardSignInBannerView: DashboardSignInBannerView = {
        let view = DashboardSignInBannerView()
        view.delegate = self
        return view
    }()

    private lazy var dashboardViewHostingController: UIViewController = {
        let view = DashboardView(measurementService: measurementService)
        return UIHostingController(
            rootView: view.environmentObject(state).environmentObject(actions)
        )
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = RuuviColor.dashboardIndicator.color
        ai.hidesWhenStopped = true
        return ai
    }()

    private var showSignInBannerConstraint: NSLayoutConstraint!
    private var hideSignInBannerConstraint: NSLayoutConstraint!

    private var tagNameTextField = UITextField()
    private let tagNameCharaterLimit: Int = 32

    private var appDidBecomeActiveToken: NSObjectProtocol?

    private var isListRefreshable: Bool = true
    private var isPulling: Bool = false

    private var state = DashboardViewState()
    private var actions = DashboardViewActions()
    var cancellables = Set<AnyCancellable>()

    deinit {
        appDidBecomeActiveToken?.invalidate()
    }
}

// MARK: - View lifecycle

extension DashboardViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
        configureRestartAnimationsOnAppDidBecomeActive()
        localize()
        output.viewDidLoad()

        actions.cardDidTap.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerDashboardCard(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerOpenCardImageView.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerOpenCardImageView(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerChart.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerChart(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerSettings.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerSettings(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerChangeBackground.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerChangeBackground(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerRename.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerRename(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerShare.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerShare(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerRemove.sink { [weak self] viewModel in
            guard let self else { return }
            self.output.viewDidTriggerRemove(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidReorder.sink { [weak self] reorderedItems in
            guard let self else { return }
            let orderedIds = reorderedItems.compactMap { viewModel -> String? in
                return viewModel.mac?.value ?? viewModel.luid?.value
            }
            self.output.viewDidReorderSensors(with: .manual, orderedIds: orderedIds)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerMoveUp.sink { [weak self] viewModel in
            guard let self else { return }
            self.handleMoveUp(for: viewModel)
        }.store(in: &cancellables)
        
        actions.cardDidTriggerMoveDown.sink { [weak self] viewModel in
            guard let self else { return }
            self.handleMoveDown(for: viewModel)
        }.store(in: &cancellables)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
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

    override func viewWillTransition(
        to size: CGSize,
        with coordinator:
        UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)
        // No additional action needed for SwiftUI view
    }
}

private extension DashboardViewController {
    @objc func handleMenuButtonTap() {
        output.viewDidTriggerMenu()
    }

    private func reloadCollectionView(redrawLayout: Bool = false) {
        // No longer needed with SwiftUI implementation
    }

    @objc func didPullToRefresh() {
        // Pull to refresh now handled by SwiftUI .refreshable
    }
}

extension DashboardViewController {
    // swiftlint:disable:next function_body_length
    private func viewToggleMenuOptions() -> UIMenu {
        // Card Type
        let imageViewTypeAction = UIAction(title: RuuviLocalization.imageCards) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .image)
        }

        let simpleViewTypeAction = UIAction(title: RuuviLocalization.simpleCards) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .simple)
        }

        simpleViewTypeAction.state = dashboardType == .simple ? .on : .off
        imageViewTypeAction.state = dashboardType == .image ? .on : .off

        let cardTypeMenu = UIMenu(
            title: RuuviLocalization.cardType,
            options: .displayInline,
            children: [
                imageViewTypeAction, simpleViewTypeAction
            ]
        )

        // Card action
        let openSensorViewAction = UIAction(title: RuuviLocalization.openSensorView) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .card)
        }

        let openHistoryViewAction = UIAction(title: RuuviLocalization.openHistoryView) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .chart)
        }

        openSensorViewAction.state = dashboardTapActionType == .card ? .on : .off
        openHistoryViewAction.state = dashboardTapActionType == .chart ? .on : .off

        let cardActionMenu = UIMenu(
            title: RuuviLocalization.cardAction,
            options: .displayInline,
            children: [
                openSensorViewAction, openHistoryViewAction
            ]
        )

        // Sensor ordering
        let resetSensorSortingOrderAction = UIAction(
            title: RuuviLocalization.resetOrder
        ) {
            [weak self] _ in
            self?.output.viewDidResetManualSorting()
        }
        resetSensorSortingOrderAction.state = .off

        let resetSensorSortingOrderMenu = UIMenu(
            title: RuuviLocalization.ordering,
            options: .displayInline,
            children: [
                resetSensorSortingOrderAction
            ]
        )

        var menuItems: [UIMenuElement] = [
            cardTypeMenu,
            cardActionMenu,
        ]

        if dashboardSortingType == .manual {
            menuItems.append(resetSensorSortingOrderMenu)
        }

        return UIMenu(
            title: "",
            children: menuItems
        )
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func cardContextMenuOption(for index: Int) -> UIMenu {
        let fullImageViewAction = UIAction(title: RuuviLocalization.fullImageView) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerOpenCardImageView(for: viewModel)
            }
        }

        let historyViewAction = UIAction(title: RuuviLocalization.historyView) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChart(for: viewModel)
            }
        }

        let settingsAction = UIAction(title: RuuviLocalization.settingsAndAlerts) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerSettings(for: viewModel)
            }
        }

        let changeBackgroundAction = UIAction(title: RuuviLocalization.changeBackground) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerChangeBackground(for: viewModel)
            }
        }

        let renameAction = UIAction(title: RuuviLocalization.rename) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerRename(for: viewModel)
            }
        }

        let shareSensorAction = UIAction(title: RuuviLocalization.TagSettings.shareButton) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerShare(for: viewModel)
            }
        }

        let moveUpAction = UIAction(title: RuuviLocalization.moveUp) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                let moveToIndex = index-1
                guard moveToIndex >= 0 else { return }
//                self?.moveItem(viewModel, from: index, to: moveToIndex)
            }
        }

        let moveDownAction = UIAction(title: RuuviLocalization.moveDown) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                guard let sSelf = self else { return }
                let moveToIndex = index+1
                guard moveToIndex < sSelf.viewModels.count else { return }
//                self?.moveItem(viewModel, from: index, to: moveToIndex)
            }
        }

        let removeSensorAction = UIAction(title: RuuviLocalization.remove) {
            [weak self] _ in
            if let viewModel = self?.viewModels[index] {
                self?.output.viewDidTriggerRemove(for: viewModel)
            }
        }

        var contextMenuActions: [UIAction] = [
            fullImageViewAction,
            historyViewAction,
            settingsAction,
            changeBackgroundAction,
            renameAction,
        ]

        // Add sensor move up and down action only if there are at least two sensors.
        // Do not show move up button for first time, and move down button for last item.
        if viewModels.count >= 1 {

          if index == 0 {
              contextMenuActions += [
                  moveDownAction,
              ]
          } else if index == viewModels.count - 1 {
              contextMenuActions += [
                  moveUpAction,
              ]
          } else {
              contextMenuActions += [
                  moveUpAction,
                  moveDownAction,
              ]
          }
        }

        let viewModel = viewModels[index]
        if viewModel.canShareTag {
            contextMenuActions.append(shareSensorAction)
        }

        contextMenuActions.append(removeSensorAction)

        return UIMenu(title: "", children: contextMenuActions)
    }

    private func showNoSignInBannerIfNeeded() {
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.3, animations: { [weak self] in
                guard let sSelf = self else { return }
                sSelf.dashboardSignInBannerView.alpha = sSelf.shouldShowSignInBanner ? 1 : 0

                if sSelf.shouldShowSignInBanner {
                    NSLayoutConstraint.deactivate([
                        sSelf.hideSignInBannerConstraint
                    ])
                    NSLayoutConstraint.activate([
                        sSelf.showSignInBannerConstraint
                    ])
                } else {
                    NSLayoutConstraint.deactivate([
                        sSelf.showSignInBannerConstraint
                    ])
                    NSLayoutConstraint.activate([
                        sSelf.hideSignInBannerConstraint
                    ])
                }
                sSelf.view.layoutIfNeeded()
            })
        }
    }
}

private extension DashboardViewController {
    func setUpUI() {
        updateNavBarTitleFont()
        setUpBaseView()
        setUpHeaderView()
        setUpContentView()
    }

    func updateNavBarTitleFont() {
        navigationController?.navigationBar.titleTextAttributes =
            [NSAttributedString.Key.font: UIFont.Muli(.bold, size: 18)]
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.dashboardBG.color

        view.addSubview(noSensorView)
        noSensorView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: view.safeBottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: 12,
                left: 12,
                bottom: 12,
                right: 12
            )
        )
        noSensorView.isHidden = true
    }

    func setUpHeaderView() {
        let leftBarButtonView = UIView(color: .clear)

        leftBarButtonView.addSubview(menuButton)
        menuButton.anchor(
            top: leftBarButtonView.topAnchor,
            leading: leftBarButtonView.leadingAnchor,
            bottom: leftBarButtonView.bottomAnchor,
            trailing: nil,
            padding: .init(top: 0, left: -16, bottom: 0, right: 0)
        )

        leftBarButtonView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: menuButton.trailingAnchor,
            bottom: nil,
            trailing: leftBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 0),
            size: .init(width: 90, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        let rightBarButtonView = UIView(color: .clear)
        rightBarButtonView.addSubview(viewButton)
        viewButton.anchor(
            top: rightBarButtonView.topAnchor,
            leading: rightBarButtonView.leadingAnchor,
            bottom: rightBarButtonView.bottomAnchor,
            trailing: rightBarButtonView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 4),
            size: .init(
                width: 0,
                height: 32
            )
        )

        let titleView = UIView(
            color: .clear
        )
        titleView.addSubview(activityIndicator)
        activityIndicator.fillSuperview()

        navigationItem.titleView = titleView
        navigationItem.leftBarButtonItem = UIBarButtonItem(customView: leftBarButtonView)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: rightBarButtonView)
    }

    func setUpContentView() {

        view.addSubview(dashboardSignInBannerView)
        dashboardSignInBannerView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor
        )
        dashboardSignInBannerView.alpha = 0

        dashboardViewHostingController.view.backgroundColor = RuuviColor.dashboardBG.color
        addChild(dashboardViewHostingController)
        view.addSubview(dashboardViewHostingController.view)
        dashboardViewHostingController.view.anchor(
            top: nil,
            leading: view.safeLeftAnchor,
            bottom: view.bottomAnchor,
            trailing: view.safeRightAnchor,
            padding: .init(
                top: 0,
                left: 12,
                bottom: 0,
                right: 12
            )
        )
        showSignInBannerConstraint = dashboardViewHostingController.view.topAnchor.constraint(
            equalTo: dashboardSignInBannerView.bottomAnchor, constant: 8
        )
        hideSignInBannerConstraint = dashboardViewHostingController.view.topAnchor.constraint(
            equalTo: view.safeTopAnchor,
            constant: 12
        )
        hideSignInBannerConstraint.isActive = true
    }



    private func configureRestartAnimationsOnAppDidBecomeActive() {
        appDidBecomeActiveToken = NotificationCenter
            .default
            .addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                // SwiftUI dashboard handles animations automatically
                // No need to manually reload
            }
    }


}

// MARK: - Helper Methods for Move Actions
private extension DashboardViewController {
    func handleMoveUp(for viewModel: CardsViewModel) {
        guard let currentIndex = viewModels.firstIndex(where: { vm in
            vm.luid != nil && vm.luid == viewModel.luid ||
                vm.mac != nil && vm.mac == viewModel.mac
        }), currentIndex > 0 else { return }
        
        // Swap items
        var newOrder = viewModels
        newOrder.swapAt(currentIndex, currentIndex - 1)
        
        // Update state
        state.updateItems(newOrder)
        
        // Notify presenter with ordered IDs
        let orderedIds = newOrder.compactMap { viewModel -> String? in
            return viewModel.mac?.value ?? viewModel.luid?.value
        }
        output.viewDidReorderSensors(with: .manual, orderedIds: orderedIds)
    }
    
    func handleMoveDown(for viewModel: CardsViewModel) {
        guard let currentIndex = viewModels.firstIndex(where: { vm in
            vm.luid != nil && vm.luid == viewModel.luid ||
                vm.mac != nil && vm.mac == viewModel.mac
        }), currentIndex < viewModels.count - 1 else { return }
        
        // Swap items
        var newOrder = viewModels
        newOrder.swapAt(currentIndex, currentIndex + 1)
        
        // Update state
        state.updateItems(newOrder)
        
        // Notify presenter with ordered IDs
        let orderedIds = newOrder.compactMap { viewModel -> String? in
            return viewModel.mac?.value ?? viewModel.luid?.value
        }
        output.viewDidReorderSensors(with: .manual, orderedIds: orderedIds)
    }

}

// MARK: - DashboardViewInput

extension DashboardViewController: DashboardViewInput {
    func applyUpdate(to viewModel: CardsViewModel) {
        // SwiftUI dashboard updates automatically via state binding
        // Update the corresponding item in the state
        if let index = viewModels.firstIndex(where: { vm in
            vm.luid != nil && vm.luid == viewModel.luid ||
                vm.mac != nil && vm.mac == viewModel.mac
        }) {
            viewModels[index] = viewModel
        }
    }

    func localize() {
        // No op.
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        let title = RuuviLocalization.Cards.BluetoothDisabledAlert.title
        let message = RuuviLocalization.Cards.BluetoothDisabledAlert.message
        let alertVC = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(
            title: RuuviLocalization.PermissionPresenter.settings,
            style: .default,
            handler: { _ in
                guard let url = URL(string: userDeclined ?
                    UIApplication.openSettingsURLString : "App-prefs:Bluetooth"),
                    UIApplication.shared.canOpenURL(url)
                else {
                    return
                }
                UIApplication.shared.open(url)
            }
        ))
        alertVC.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alertVC, animated: true)
    }

    func showNoSensorsAddedMessage(show: Bool) {
        noSensorView.updateView()
        noSensorView.isHidden = !show
        dashboardViewHostingController.view.isHidden = show
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

    func showAlreadyLoggedInAlert(with email: String) {
        let message = RuuviLocalization.Cards.Alert.AlreadyLoggedIn.message(email)
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: RuuviLocalization.ok, style: .cancel, handler: nil))
        present(alert, animated: true)
    }

    func showSensorNameRenameDialog(
        for viewModel: CardsViewModel,
        sortingType: DashboardSortingType
    ) {
        let defaultName = GlobalHelpers.ruuviTagDefaultName(
            from: viewModel.mac?.mac,
            luid: viewModel.luid?.value
        )
        let alert = UIAlertController(
            title: RuuviLocalization.TagSettings.TagNameTitleLabel.text,
            message: sortingType == .alphabetical ?
                RuuviLocalization.TagSettings.TagNameTitleLabel.Rename.text : nil,
            preferredStyle: .alert
        )
        alert.addTextField { [weak self] alertTextField in
            guard let self else { return }
            alertTextField.delegate = self
            alertTextField.text = (defaultName == viewModel.name) ? nil : viewModel.name
            alertTextField.placeholder = defaultName
            tagNameTextField = alertTextField
        }
        let action = UIAlertAction(title: RuuviLocalization.ok, style: .default) { [weak self] _ in
            guard let self else { return }
            if let name = tagNameTextField.text, !name.isEmpty {
                output.viewDidRenameTag(to: name, viewModel: viewModel)
            } else {
                output.viewDidRenameTag(to: defaultName, viewModel: viewModel)
            }
        }
        let cancelAction = UIAlertAction(title: RuuviLocalization.cancel, style: .cancel)
        alert.addAction(action)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }

    func showSensorSortingResetConfirmationDialog() {
        let message = RuuviLocalization.resetOrderConfirmation
        let alert = UIAlertController(
            title: nil,
            message: message,
            preferredStyle: .alert
        )

        let cancelTitle = RuuviLocalization.cancel
        alert.addAction(
            UIAlertAction(
                title: cancelTitle,
                style: .cancel,
                handler: nil
            )
        )

        let confirmTitle = RuuviLocalization.confirm
        alert.addAction(
            UIAlertAction(
                title: confirmTitle,
                style: .default,
                handler: { [weak self] _ in
                    self?.output.viewDidReorderSensors(
                        with: .alphabetical, orderedIds: []
                    )
                }
            )
        )
        present(alert, animated: true)
    }
}

extension DashboardViewController: RuuviServiceMeasurementDelegate {
    func measurementServiceDidUpdateUnit() {
        guard isViewLoaded
        else {
            return
        }
        // SwiftUI dashboard updates automatically when units change
    }
}

extension DashboardViewController: DashboardCellDelegate {
    func didTapAlertButton(for viewModel: CardsViewModel) {
        output.viewDidTriggerSettings(for: viewModel)
    }
}

extension DashboardViewController: NoSensorViewDelegate {
    func didTapSignInButton(sender _: NoSensorView) {
        output.viewDidTriggerSignIn()
    }

    func didTapAddSensorButton(sender _: NoSensorView) {
        output.viewDidTriggerAddSensors()
    }

    func didTapBuySensorButton(sender _: NoSensorView) {
        output.viewDidTriggerBuySensors()
    }
}

private extension DashboardViewController {
    func updateUI() {
        showNoSensorsAddedMessage(show: viewModels.isEmpty)
        // SwiftUI dashboard updates automatically via state binding
    }
}

// MARK: - UITextFieldDelegate

extension DashboardViewController: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,

        replacementString string: String
    ) -> Bool {
        guard let text = textField.text
        else {
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

// MARK: - DashboardSignInBannerViewDelegate
extension DashboardViewController: DashboardSignInBannerViewDelegate {

    func didTapCloseButton(sender: DashboardSignInBannerView) {
        output.viewDidHideSignInBanner()
    }

    func didTapSignInButton(sender _: DashboardSignInBannerView) {
        output.viewDidTriggerSignIn()
    }
}
