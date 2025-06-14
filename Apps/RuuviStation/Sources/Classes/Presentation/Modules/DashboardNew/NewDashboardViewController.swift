import SwiftUI
import UIKit
import RuuviLocalization
import RuuviOntology
import Combine

class NewDashboardViewController: UIViewController, NewDashboardViewInput {
    // MARK: DashboardViewInput conformance

    // ------------------------------------------------------------------

    var viewModels: [CardsViewModel] = [] {
        didSet {
//            viewState.cardItems = viewModels
        }
    }

    var dashboardType: DashboardType = .simple {
        didSet {
            viewState.dashboardType = dashboardType
        }
    }

    var dashboardTapActionType: DashboardTapActionType = .card {
        didSet {
            viewState.cardTapAction = dashboardTapActionType
        }
    }

    var dashboardSortingType: DashboardSortingType = .alphabetical {
        didSet {
            // Do something
        }
    }

    var isRefreshing: Bool = false {
        didSet {
            if isRefreshing {
                activityIndicator.startAnimating()
            } else {
                activityIndicator.stopAnimating()
            }
        }
    }

    var shouldShowSignInBanner: Bool = false {
        didSet {
            // Do something
        }
    }

    func showNoSensorsAddedMessage(show: Bool) {
        // Do something
    }

    func showBluetoothDisabled(userDeclined: Bool) {
        // Do something
    }

    func showKeepConnectionDialogChart(for viewModel: CardsViewModel) {
        // Do something
    }

    func showKeepConnectionDialogSettings(for viewModel: CardsViewModel) {
        // Do something
    }

    func showReverseGeocodingFailed() {
        // Do something
    }

    func showAlreadyLoggedInAlert(with email: String) {
        // Do something
    }

    func showSensorNameRenameDialog(
        for viewModel: CardsViewModel,
        sortingType: DashboardSortingType
    ) {
        // Do something
    }

    func showSensorSortingResetConfirmationDialog() {
        // Do something
    }


    private var cancellables = Set<AnyCancellable>()

    // MARK: Init
    override init(
        nibName nibNameOrNil: String?,
        bundle nibBundleOrNil: Bundle?
    ) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    convenience init(viewState: DashboardViewState, store: SensorStore) {
        self.init(nibName: nil, bundle: nil)
        self.viewState = viewState
        self.store = store
    }

    // MARK: Public
    var viewState: DashboardViewState!
    var store: SensorStore?
    var output: DashboardViewOutput!

    // MARK: UI Components
    private lazy var headerView = UIView(color: .clear)
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

    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.ruuviLogo.image.withRenderingMode(.alwaysTemplate),
            contentMode: .scaleAspectFit
        )
        iv.backgroundColor = .clear
        iv.tintColor = RuuviColor.logoTintColor.color
        return iv
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = RuuviColor.dashboardIndicator.color
        ai.hidesWhenStopped = true
        return ai
    }()

    private lazy var viewButton: RuuviContextMenuButton =
        .init(
            menu: viewToggleMenuOptions(),
            titleColor: RuuviColor.dashboardIndicator.color,
            title: RuuviLocalization.view,
            icon: RuuviAsset.arrowDropDown.image,
            iconTintColor: RuuviColor.logoTintColor.color,
            iconSize: .init(width: 14, height: 14),
            leadingPadding: 6,
            trailingPadding: 6,
            preccedingIcon: false
        )

    private lazy var dashboardContentView: UIViewController = {
        if #available(iOS 17.0, *) {
            let controller = UIHostingController(
                rootView: DashboardCardsView(
                    // swiftlint:disable:next force_cast
                    store: self.store! as! ModernSensorStore
                ).environmentObject(viewState)
            )
            controller.view.backgroundColor = .clear
            return controller
        } else {
            let controller = UIHostingController(
                rootView: DashboardCardsViewLegacy(
                    // swiftlint:disable:next force_cast
                    store: self.store! as! LegacySensorStore
                ).environmentObject(viewState)
            )
            controller.view.backgroundColor = .clear
            return controller
        }
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpViews()
        output.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output.viewWillAppear()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        output.viewWillDisappear()
    }
}

// MARK: UI Setup

extension NewDashboardViewController {
    private func setUpViews() {
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = RuuviColor.dashboardBG.color
        setUpHeaderView()
        setUpCardsView()
    }

    private func setUpHeaderView() {
        headerView.addSubview(menuButton)
        menuButton.anchor(
            top: headerView.topAnchor,
            leading: headerView.leadingAnchor,
            bottom: headerView.bottomAnchor,
            trailing: nil,
            padding: .init(top: 0, left: 8, bottom: 0, right: 0)
        )

        headerView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: menuButton.trailingAnchor,
            bottom: nil,
            trailing: nil,
            size: .init(width: 90, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        headerView.addSubview(viewButton)
        viewButton.anchor(
            top: headerView.topAnchor,
            leading: nil,
            bottom: headerView.bottomAnchor,
            trailing: headerView.trailingAnchor,
            padding: .init(top: 0, left: 0, bottom: 0, right: 8)
        )

        headerView.addSubview(activityIndicator)
        activityIndicator.centerInSuperview()

        view.addSubview(headerView)
        headerView.anchor(
            top: view.safeTopAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            size: .init(width: 0, height: 44)
        )
    }

    private func setUpCardsView() {
        dashboardContentView.willMove(toParent: self)
        addChild(dashboardContentView)
        view.addSubview(dashboardContentView.view)
        dashboardContentView.view.anchor(
            top: headerView.bottomAnchor,
            leading: headerView.leadingAnchor,
            bottom: view.safeBottomAnchor,
            trailing: headerView.trailingAnchor,
            padding: .init(top: 8, left: 0, bottom: 0, right: 0)
        )
        dashboardContentView.didMove(toParent: self)
    }
}

// MARK: Private Actions

extension NewDashboardViewController {
    @objc func handleMenuButtonTap() {
        output.viewDidTriggerMenu()
    }

    private func viewToggleMenuOptions() -> UIMenu {
        // Card Type
        let imageViewTypeAction = UIAction(title: RuuviLocalization.imageCards) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .image)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let simpleViewTypeAction = UIAction(title: RuuviLocalization.simpleCards) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardType(dashboardType: .simple)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
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
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
        }

        let openHistoryViewAction = UIAction(title: RuuviLocalization.openHistoryView) {
            [weak self] _ in
            self?.output.viewDidChangeDashboardTapAction(type: .chart)
            self?.viewButton.updateMenu(with: self?.viewToggleMenuOptions())
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
}

//extension NewDashboardViewController {
//    public func makeViewController() -> UIViewController {
//        let controller = UIHostingController(rootView: DashboardView())
//        return controller
//    }
//}
