import UIKit
import RuuviLocalization
import RuuviOntology

enum CardsMenuMode {
    case legacy
    case modern
}

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

// MARK: - Legacy Menu Types (for 3-button layout)
enum LegacyMenuType: String, CaseIterable {
    case alerts
    case measurementGraph // Combined measurement/graph button
    case settings

    var icon: UIImage {
        switch self {
        case .alerts:
            return RuuviAsset.CardsMenu.iconAlerts.image
        case .measurementGraph:
            return RuuviAsset.CardsMenu.iconGraph.image
        case .settings:
            return RuuviAsset.CardsMenu.iconSettings.image
        }
    }
}

// MARK: - Custom Tab Button (Modern)
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

    // MARK: - Alert State Updates
    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        guard menuType == .alerts else { return }

        // Remove existing animations
        iconImageView.layer.removeAllAnimations()

        guard let snapshot = snapshot,
              snapshot.metadata.isAlertAvailable else {
            iconImageView.image = nil
            isUserInteractionEnabled = false
            return
        }

        isUserInteractionEnabled = true

        switch snapshot.alertData.alertState {
        case .empty, .none:
            if snapshot.metadata.isAlertAvailable {
                iconImageView.image = RuuviAsset.CardsMenu.iconAlertsOff.image
                iconImageView.tintColor = .white
                removeAlertAnimations(alpha: 0.5)
            }

        case .registered:
            iconImageView.image = RuuviAsset.CardsMenu.iconAlerts.image
            iconImageView.tintColor = .white
            removeAlertAnimations(alpha: 1.0)

        case .firing:
            iconImageView.image = RuuviAsset.CardsMenu.iconAlertActive.image
            iconImageView.tintColor = RuuviColor.orangeColor.color
            iconImageView.alpha = 1.0
            startAlertAnimation()
        }
    }

    private func startAlertAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                options: [.repeat, .autoreverse, .beginFromCurrentState],
                animations: {
                    self?.iconImageView.alpha = 0.0
                }
            )
        }
    }

    private func removeAlertAnimations(alpha: Double = 1.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.iconImageView.layer.removeAllAnimations()
            self?.iconImageView.alpha = alpha
        }
    }
}

// MARK: - Custom Tab Button (Legacy)
private class LegacyMenuButton: UIButton {
    let menuType: LegacyMenuType
    private let iconImageView = UIImageView()

    // For the combined measurement/graph button
    private var currentSubType: CardsMenuType = .measurement {
        didSet {
            updateIcon()
        }
    }

    init(menuType: LegacyMenuType) {
        self.menuType = menuType
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        // Configure icon
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(iconImageView)

        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 34),
            iconImageView.heightAnchor.constraint(equalToConstant: 34),
        ])

        // Button configuration
        backgroundColor = .clear
        widthAnchor.constraint(equalToConstant: 34).isActive = true

        // Set initial icon
        updateIcon()
    }

    private func updateIcon() {
        if menuType == .measurementGraph {
            // Show the opposite icon - what will happen when tapped
            iconImageView.image =
                    currentSubType == .measurement ? CardsMenuType.graph.icon : CardsMenuType.measurement.icon
        } else {
            // For alerts and settings, show the normal icon
            iconImageView.image = menuType.icon
        }
    }

    func setCurrentSubType(_ subType: CardsMenuType) {
        currentSubType = subType
    }

    // MARK: - Alert State Updates (Legacy)
    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        guard menuType == .alerts else { return }

        // Remove existing animations
        iconImageView.layer.removeAllAnimations()

        guard let snapshot = snapshot,
              snapshot.metadata.isAlertAvailable else {
            iconImageView.image = nil
            isUserInteractionEnabled = false
            return
        }

        isUserInteractionEnabled = true

        // Check for muted alerts
        switch snapshot.alertData.alertState {
        case .empty, .none:
            if snapshot.metadata.isAlertAvailable {
                iconImageView.image = RuuviAsset.CardsMenu.iconAlertsOff.image
                iconImageView.tintColor = .white
                removeAlertAnimations(alpha: 0.5)
            }

        case .registered:
            iconImageView.image = RuuviAsset.CardsMenu.iconAlerts.image
            iconImageView.tintColor = .white
            removeAlertAnimations(alpha: 1.0)

        case .firing:
            iconImageView.image = RuuviAsset.CardsMenu.iconAlertActive.image
            iconImageView.tintColor = RuuviColor.orangeColor.color
            iconImageView.alpha = 1.0
            startAlertAnimation()
        }
    }

    private func startAlertAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                options: [.repeat, .autoreverse, .beginFromCurrentState],
                animations: {
                    self?.iconImageView.alpha = 0.0
                }
            )
        }
    }

    private func removeAlertAnimations(alpha: Double = 1.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.iconImageView.layer.removeAllAnimations()
            self?.iconImageView.alpha = alpha
        }
    }
}

// MARK: - Main Menu Bar View
class CardsMenuBarView: UIView {

    // MARK: - Properties
    private let stackView = UIStackView()
    private let underlineView = UIView()

    // Modern mode buttons
    private var modernButtons: [CardsMenuButton] = []

    // Legacy mode buttons
    private var legacyButtons: [LegacyMenuButton] = []

    private var underlineLeadingConstraint: NSLayoutConstraint!

    private var selectedMenu: CardsMenuType = .measurement
    private let mode: CardsMenuMode
    private var hasAppeared = false

    // MARK: - Alert State Tracking
    private var currentAlertSnapshot: RuuviTagCardSnapshot?

    // MARK: - Callbacks
    var onTabChanged: ((CardsMenuType) -> Void)?

    // MARK: - Init
    init(menuMode: CardsMenuMode) {
        self.mode = menuMode
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Methods
    func setSelectedTab(_ tab: CardsMenuType, animated: Bool = true) {
        guard tab != selectedMenu else { return }
        selectedMenu = tab

        if mode == .modern {
            updateSelection(animated: animated)
        } else {
            updateLegacySelection()
        }

        onTabChanged?(tab)
    }

    func getCurrentTab() -> CardsMenuType {
        return selectedMenu
    }

    // MARK: - Alert State Management
    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        // Only update if snapshot actually changed
        guard currentAlertSnapshot?.id != snapshot?.id ||
              currentAlertSnapshot?.alertData != snapshot?.alertData ||
              currentAlertSnapshot?.metadata.isAlertAvailable != snapshot?.metadata.isAlertAvailable else {
            return
        }

        currentAlertSnapshot = snapshot

        // Update the appropriate buttons based on mode
        if mode == .modern {
            if let alertButton = modernButtons.first(where: { $0.menuType == .alerts }) {
                alertButton.updateAlertState(for: snapshot)
            }
        } else {
            if let alertButton = legacyButtons.first(where: { $0.menuType == .alerts }) {
                alertButton.updateAlertState(for: snapshot)
            }
        }
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        // Initialize underline position after first layout (modern mode only)
        if mode == .modern && !hasAppeared && bounds.width > 0 {
            hasAppeared = true
            updateSelection(animated: false)
        }

        // Update underline position after layout changes (modern mode only)
        if mode == .modern && bounds.width > 0 {
            updateUnderlinePosition()
        }
    }

    // MARK: - Private Methods
    private func setupUI() {
        backgroundColor = .clear

        if mode == .modern {
            setupModernUI()
        } else {
            setupLegacyUI()
        }

        setupStackView()
        setupConstraints()
    }

    private func setupModernUI() {
        // Create buttons for each menu type
        modernButtons = CardsMenuType.allCases.map { menuType in
            let button = CardsMenuButton(menuType: menuType)
            button.addTarget(self, action: #selector(modernButtonTapped(_:)), for: .touchUpInside)
            return button
        }

        // Add buttons to stack view
        modernButtons.forEach { stackView.addArrangedSubview($0) }

        // Configure underline view
        underlineView.backgroundColor = .white
        underlineView.layer.cornerRadius = 1
        underlineView.translatesAutoresizingMaskIntoConstraints = false

        // Add subviews
        addSubview(stackView)
        addSubview(underlineView)
    }

    private func setupLegacyUI() {
        // Create 3 buttons for legacy mode
        legacyButtons = LegacyMenuType.allCases.map { menuType in
            let button = LegacyMenuButton(menuType: menuType)
            button.addTarget(self, action: #selector(legacyButtonTapped(_:)), for: .touchUpInside)
            return button
        }

        // Add buttons to stack view
        legacyButtons.forEach { stackView.addArrangedSubview($0) }

        // Add stack view only (no underline)
        addSubview(stackView)
    }

    private func setupStackView() {
        stackView.axis = .horizontal
        stackView.spacing = 2
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupConstraints() {
        if mode == .modern {

            // Stack view constraints
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
                stackView.topAnchor.constraint(equalTo: topAnchor, constant: -2),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
            ])

            underlineLeadingConstraint = underlineView.leadingAnchor.constraint(equalTo: leadingAnchor)

            NSLayoutConstraint.activate([
                underlineLeadingConstraint,
                underlineView.bottomAnchor
                    .constraint(equalTo: bottomAnchor, constant: -4),
                underlineView.widthAnchor.constraint(equalToConstant: 16),
                underlineView.heightAnchor.constraint(equalToConstant: 2),
            ])

        } else {
            // Stack view constraints
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
                stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
                stackView.topAnchor.constraint(equalTo: topAnchor, constant: 0),
                stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 0),
            ])
        }
    }

    @objc private func modernButtonTapped(_ sender: CardsMenuButton) {
        guard sender.menuType != selectedMenu else { return }
        selectedMenu = sender.menuType
        updateSelection(animated: true)
        onTabChanged?(selectedMenu)
    }

    @objc private func legacyButtonTapped(_ sender: LegacyMenuButton) {
        switch sender.menuType {
        case .alerts:
            selectedMenu = .alerts

        case .measurementGraph:
            // Toggle between measurement and graph
            if selectedMenu == .measurement {
                selectedMenu = .graph
            } else if selectedMenu == .graph {
                selectedMenu = .measurement
            } else {
                // Coming from another tab, default to measurement
                selectedMenu = .measurement
            }

        case .settings:
            selectedMenu = .settings
        }

        updateLegacySelection()
        onTabChanged?(selectedMenu)
    }

    private func updateLegacySelection() {
        // Update the measurement/graph button to show correct icon
        if let measurementGraphButton = legacyButtons.first(where: { $0.menuType == .measurementGraph }) {
            if selectedMenu == .measurement || selectedMenu == .graph {
                measurementGraphButton.setCurrentSubType(selectedMenu)
            }
        }
    }

    private func updateSelection(animated: Bool) {
        guard mode == .modern else { return }

        // Update underline position
        guard let selectedButtonIndex = modernButtons.firstIndex(where: { $0.menuType == selectedMenu }) else { return }
        let selectedButton = modernButtons[selectedButtonIndex]

        // Ensure layout is up to date for correct frame calculations
        layoutIfNeeded()

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
                    self.layoutIfNeeded()
                },
                completion: nil
            )
        } else {
            underlineLeadingConstraint.constant = newConstant
            layoutIfNeeded()
        }
    }

    private func updateUnderlinePosition() {
        guard let selectedButtonIndex = modernButtons.firstIndex(where: { $0.menuType == selectedMenu }) else { return }
        let selectedButton = modernButtons[selectedButtonIndex]
        let buttonCenterX = selectedButton.frame.midX
        let underlineWidth: CGFloat = 16
        underlineLeadingConstraint.constant = buttonCenterX - (underlineWidth / 2)
    }
}
