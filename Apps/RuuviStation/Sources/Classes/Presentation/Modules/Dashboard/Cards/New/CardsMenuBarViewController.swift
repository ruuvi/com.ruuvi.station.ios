import UIKit
import RuuviLocalization

// MARK: - Models
enum CardsMenuType: String, CaseIterable {
    case measurement
    case graph
    case alerts
    case settings

    var icon: UIImage {
        switch self {
        case .measurement:
            return RuuviAsset.CardsMenu.iconMeasurement.image
        case .graph:
            return RuuviAsset.CardsMenu.iconGraph.image
        case .alerts:
            return RuuviAsset.CardsMenu.iconAlerts.image
        case .settings:
            return RuuviAsset.CardsMenu.iconSettings.image
        }
    }
}

// MARK: - Custom Tab Button
private class CardsMenuButton: UIButton {
    let menuType: CardsMenuType
    private let iconImageView = UIImageView()

    init(menuType: CardsMenuType) {
        self.menuType = menuType
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Configure icon
        iconImageView.image = menuType.icon
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 30),
            iconImageView.heightAnchor.constraint(equalToConstant: 30),
        ])

        // Button configuration
        backgroundColor = .clear
        widthAnchor.constraint(equalToConstant: 34).isActive = true
    }
}

// MARK: - Main Menu Bar
class CardsMenuBarViewController: UIViewController {

    // MARK: - Properties
    private let stackView = UIStackView()
    private let underlineView = UIView()
    private var buttons: [CardsMenuButton] = []
    private var underlineLeadingConstraint: NSLayoutConstraint!

    private var selectedMenu: CardsMenuType = .measurement

    // MARK: - Callbacks
    var onTabChanged: ((CardsMenuType) -> Void)?

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Initialize underline position after frames are set
        updateSelection(animated: false)
    }

    // MARK: - Public Methods
    func setSelectedTab(_ tab: CardsMenuType, animated: Bool = true) {
        guard tab != selectedMenu else { return }
        selectedMenu = tab
        updateSelection(animated: animated)
        onTabChanged?(tab)
    }

    func getCurrentTab() -> CardsMenuType {
        return selectedMenu
    }

    // MARK: - Private Methods
    private func setupUI() {
        view.backgroundColor = .clear

        // Create buttons for each menu type
        buttons = CardsMenuType.allCases.map { menuType in
            let button = CardsMenuButton(menuType: menuType)
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            return button
        }

        // Configure stack view
        stackView.axis = .horizontal
        stackView.spacing = 2
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false

        // Add buttons to stack view
        buttons.forEach { stackView.addArrangedSubview($0) }

        // Configure underline view
        underlineView.backgroundColor = .white
        underlineView.layer.cornerRadius = 1
        underlineView.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        view.addSubview(stackView)
        view.addSubview(underlineView)

        // Setup constraints
        setupConstraints()
    }

    private func setupConstraints() {
        // Stack view constraints
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: -2),
            stackView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -2),
        ])

        // Underline constraints - start with first button position
        underlineLeadingConstraint = underlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor)

        NSLayoutConstraint.activate([
            underlineLeadingConstraint,
            underlineView.bottomAnchor
                .constraint(equalTo: view.bottomAnchor, constant: -4),
            underlineView.widthAnchor.constraint(equalToConstant: 16),
            underlineView.heightAnchor.constraint(equalToConstant: 2),
        ])
    }

    @objc private func buttonTapped(_ sender: CardsMenuButton) {
        guard sender.menuType != selectedMenu else { return }
        selectedMenu = sender.menuType
        updateSelection(animated: true)
        onTabChanged?(selectedMenu)
    }

    private func updateSelection(animated: Bool) {

        // Update underline position
        guard let selectedButtonIndex = buttons.firstIndex(where: { $0.menuType == selectedMenu }) else { return }
        let selectedButton = buttons[selectedButtonIndex]

        // Ensure layout is up to date for correct frame calculations
        view.layoutIfNeeded()

        // Calculate the center position of the selected button
        let buttonCenterX = selectedButton.frame.midX
        let underlineWidth: CGFloat = 16
        let newConstant = buttonCenterX - (underlineWidth / 2)

        if animated {
            UIView.animate(
                withDuration: 0.6,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.curveEaseInOut, .allowUserInteraction],
                animations: {
                    self.underlineLeadingConstraint.constant = newConstant
                    self.view.layoutIfNeeded()
                },
                completion: nil
            )
        } else {
            underlineLeadingConstraint.constant = newConstant
            view.layoutIfNeeded()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update underline position after layout changes (e.g., rotation)
        // Only update if we have a valid frame
        guard view.bounds.width > 0 else { return }

        if let selectedButtonIndex = buttons.firstIndex(where: { $0.menuType == selectedMenu }) {
            let selectedButton = buttons[selectedButtonIndex]
            let buttonCenterX = selectedButton.frame.midX
            let underlineWidth: CGFloat = 16
            underlineLeadingConstraint.constant = buttonCenterX - (underlineWidth / 2)
        }
    }
}
