import UIKit
import RuuviLocalization

class NewCardsLandingViewController: UIViewController {

    // Base
    private lazy var cardBackgroundView = CardsBackgroundView()
    private lazy var chartViewBackground = UIView(color: RuuviColor.graphBGColor.color)

    // Header
    private lazy var headerView = UIView(color: .clear)
    // Ruuvi Logo
    private lazy var ruuviLogoView: UIImageView = {
        let iv = UIImageView(
            image: RuuviAsset.ruuviLogo.image.withRenderingMode(.alwaysTemplate),
            contentMode: .scaleAspectFit
        )
        iv.tintColor = .white
        return iv
    }()

    // Action Buttons
    private lazy var backButtonView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear

        let iv = UIImageView(image: RuuviAsset.chevronBack.image)
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .clear
        iv.tintColor = .white
        view.addSubview(iv)
        iv.fillSuperview(padding: .init(top: 10, left: 8, bottom: 10, right: 0))

        view.addSubview(backButton)
        backButton.fillSuperview()

        return view
    }()

    private lazy var backButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(backButtonDidTap), for: .touchUpInside)
        return button
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.color = .white
        ai.hidesWhenStopped = true
        return ai
    }()

    private lazy var menuBarView: CardsMenuBarViewController = {
        let vc = CardsMenuBarViewController()
        vc.view.backgroundColor = .clear
        return vc
    }()

    // Secondary Toolbar
    private lazy var secondaryToolbarView = UIView(color: .clear)
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
        label.text = "Very very long name testing because this is tricky"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 2
        label.font = UIFont.Muli(.extraBold, size: 20)
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpUI()
    }
}

private extension NewCardsLandingViewController {
    func setUpUI() {
        setUpBaseView()
        setUpHeaderView()
        setUpSecondaryToolbarView()
    }

    func setUpBaseView() {
        view.backgroundColor = RuuviColor.primary.color

        view.addSubview(cardBackgroundView)
        cardBackgroundView.fillSuperview()

        view.addSubview(chartViewBackground)
        chartViewBackground.fillSuperview()
        chartViewBackground.alpha = 0
    }

    func setUpHeaderView() {
        view.addSubview(headerView)
        headerView
            .anchor(
                top: view.safeTopAnchor,
                leading: view.safeLeftAnchor,
                bottom: nil,
                trailing: view.safeRightAnchor,
                size: .init(width: 0, height: 40)
            )

        headerView.addSubview(backButtonView)
        backButtonView.anchor(
            top: headerView.topAnchor,
            leading: headerView.leadingAnchor,
            bottom: headerView.bottomAnchor,
            trailing: nil,
            size: .init(width: 40, height: 40)
        )

        headerView.addSubview(ruuviLogoView)
        ruuviLogoView.anchor(
            top: nil,
            leading: backButton.trailingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 0, left: 20, bottom: 0, right: 0),
            size: .init(width: 90, height: 22)
        )
        ruuviLogoView.centerYInSuperview()

        headerView.addSubview(activityIndicator)
        activityIndicator.centerInSuperview()

        addChild(menuBarView)
        headerView.addSubview(menuBarView.view)
        menuBarView.didMove(toParent: self)
        menuBarView.view
            .anchor(
                top: headerView.topAnchor,
                leading: nil,
                bottom: headerView.bottomAnchor,
                trailing: headerView.trailingAnchor,
                padding: .init(top: 0, left: 0, bottom: 0, right: 10)
            )
        menuBarView.onTabChanged = { [weak self] tab in
            self?.handleTabChange(tab)
        }
    }

    func setUpSecondaryToolbarView() {
        view.addSubview(secondaryToolbarView)
        secondaryToolbarView.anchor(
            top: headerView.bottomAnchor,
            leading: view.safeLeftAnchor,
            bottom: nil,
            trailing: view.safeRightAnchor,
            padding: .init(top: 2, left: 0, bottom: 0, right: 0)
        )

        secondaryToolbarView.addSubview(cardLeftArrowButton)
        cardLeftArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: secondaryToolbarView.leadingAnchor,
            bottom: nil,
            trailing: nil,
            padding: .init(top: 6, left: 4, bottom: 0, right: 0)
        )

        secondaryToolbarView.addSubview(cardRightArrowButton)
        cardRightArrowButton.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: nil,
            bottom: nil,
            trailing: secondaryToolbarView.trailingAnchor,
            padding: .init(top: 6, left: 0, bottom: 0, right: 4)
        )

        secondaryToolbarView.addSubview(ruuviTagNameLabel)
        ruuviTagNameLabel.anchor(
            top: secondaryToolbarView.topAnchor,
            leading: cardLeftArrowButton.trailingAnchor,
            bottom: secondaryToolbarView.bottomAnchor,
            trailing: cardRightArrowButton.leadingAnchor,
            padding: .init(top: 8, left: 4, bottom: 6, right: 4)
        )
    }
}

private extension NewCardsLandingViewController {
    @objc func backButtonDidTap() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.popViewController(animated: true)
    }

    private func handleTabChange(_ tab: CardsMenuType) {
        switch tab {
        case .measurement:
            // Handle measurement tab selection
            print("Measurement tab selected")
        case .graph:
            // Handle graph tab selection
            print("Graph tab selected")
        case .alerts:
            // Handle alerts tab selection
            print("Alerts tab selected")
        case .settings:
            // Handle settings tab selection
            print("Settings tab selected")
        }
    }

    @objc private func cardLeftArrowButtonDidTap() {
        // TODO:
    }

    @objc private func cardRightArrowButtonDidTap() {
        // TODO:
    }
}
