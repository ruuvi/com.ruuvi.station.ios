import UIKit
import RuuviOntology

final class CardsMenuBarView: UIView {

    // MARK: - Properties
    private let stackView = UIStackView()
    private let underlineView = UIView()
    private var modernButtons: [CardsMenuButton] = []
    private var legacyButtons: [CardsLegacyMenuButton] = []
    private var underlineLeadingConstraint: NSLayoutConstraint!
    private var selectedMenu: CardsMenuType = .measurement
    private let mode: CardsMenuMode
    private var hasAppeared = false

    // MARK: - Constants
    private enum Constants {
        static let stackSpacing: CGFloat = 2
        static let modernTopBottomInset: CGFloat = -2
        static let underlineWidth: CGFloat = 16
        static let underlineHeight: CGFloat = 2
        static let underlineBottomOffset: CGFloat = -4
        static let underlineCornerRadius: CGFloat = 1
        static let animationDuration: Double = 0.6
        static let springDamping: CGFloat = 0.8
        static let springVelocity: CGFloat = 0.5
    }

    // MARK: - Callbacks
    var onTabChanged: ((CardsMenuType) -> Void)?

    // MARK: - Initialization
    init(menuMode: CardsMenuMode) {
        self.mode = menuMode
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Interface
    func setSelectedTab(
        _ tab: CardsMenuType,
        animated: Bool = true,
        notify: Bool = true
    ) {
        guard tab != selectedMenu else { return }
        selectedMenu = tab

        if mode == .modern {
            updateSelection(animated: animated)
        } else {
            updateLegacySelection()
        }

        if notify {
            onTabChanged?(tab)
        }
    }

    func getCurrentTab() -> CardsMenuType {
        return selectedMenu
    }

    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        if mode == .modern {
            modernButtons.first(where: { $0.menuType == .alerts })?.updateAlertState(for: snapshot)
        } else {
            legacyButtons.first(where: { $0.menuType == .alerts })?.updateAlertState(for: snapshot)
        }
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        guard mode == .modern && bounds.width > 0 else { return }

        if !hasAppeared {
            hasAppeared = true
            updateSelection(animated: false)
        } else {
            updateUnderlinePosition()
        }
    }

    // MARK: - Setup
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
        createModernButtons()
        setupUnderlineView()
        addSubview(stackView)
        addSubview(underlineView)
    }

    private func setupLegacyUI() {
        createLegacyButtons()
        addSubview(stackView)
    }

    private func createModernButtons() {
        modernButtons = CardsMenuType.allCases.map { menuType in
            let button = CardsMenuButton(menuType: menuType)
            button.addTarget(self, action: #selector(modernButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            return button
        }
    }

    private func createLegacyButtons() {
        legacyButtons = CardsLegacyMenuType.allCases.map { menuType in
            let button = CardsLegacyMenuButton(menuType: menuType)
            button.addTarget(self, action: #selector(legacyButtonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            return button
        }
    }

    private func setupUnderlineView() {
        underlineView.backgroundColor = .white
        underlineView.layer.cornerRadius = Constants.underlineCornerRadius
        underlineView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupStackView() {
        stackView.axis = .horizontal
        stackView.spacing = Constants.stackSpacing
        stackView.distribution = .equalSpacing
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupConstraints() {
        if mode == .modern {
            setupModernConstraints()
        } else {
            setupLegacyConstraints()
        }
    }

    private func setupModernConstraints() {
        underlineLeadingConstraint = underlineView.leadingAnchor.constraint(equalTo: leadingAnchor)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: Constants.modernTopBottomInset),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: Constants.modernTopBottomInset),

            underlineLeadingConstraint,
            underlineView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: Constants.underlineBottomOffset),
            underlineView.widthAnchor.constraint(equalToConstant: Constants.underlineWidth),
            underlineView.heightAnchor.constraint(equalToConstant: Constants.underlineHeight),
        ])
    }

    private func setupLegacyConstraints() {
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Button Actions
    @objc private func modernButtonTapped(_ sender: CardsMenuButton) {
        guard sender.menuType != selectedMenu else { return }
        selectedMenu = sender.menuType
        updateSelection(animated: true)
        onTabChanged?(selectedMenu)
    }

    @objc private func legacyButtonTapped(_ sender: CardsLegacyMenuButton) {
        handleLegacyButtonTap(for: sender.menuType)
        updateLegacySelection()
    }

    private func handleLegacyButtonTap(for menuType: CardsLegacyMenuType) {
        switch menuType {
        case .measurementGraph:
            toggleMeasurementGraph()
        case .alerts:
            onTabChanged?(.alerts)
        case .settings:
            onTabChanged?(.settings)
        }
    }

    private func toggleMeasurementGraph() {
        selectedMenu = selectedMenu == .measurement ? .graph : .measurement
        onTabChanged?(selectedMenu)
    }

    // MARK: - Selection Updates
    private func updateLegacySelection() {
        guard let measurementGraphButton = legacyButtons.first(where: {
            $0.menuType == .measurementGraph
        }) else { return }

        if selectedMenu == .measurement || selectedMenu == .graph {
            measurementGraphButton.setCurrentSubType(selectedMenu)
        }
    }

    private func updateSelection(animated: Bool) {
        guard mode == .modern,
              let selectedButtonIndex = modernButtons.firstIndex(where: {
                  $0.menuType == selectedMenu
              }) else { return }

        let selectedButton = modernButtons[selectedButtonIndex]
        layoutIfNeeded()

        let buttonCenterX = selectedButton.frame.midX
        let newConstant = buttonCenterX - (Constants.underlineWidth / 2)

        if animated {
            animateUnderline(to: newConstant)
        } else {
            underlineLeadingConstraint.constant = newConstant
            layoutIfNeeded()
        }
    }

    private func animateUnderline(to constant: CGFloat) {
        UIView.animate(
            withDuration: Constants.animationDuration,
            delay: 0,
            usingSpringWithDamping: Constants.springDamping,
            initialSpringVelocity: Constants.springVelocity,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                self.underlineLeadingConstraint.constant = constant
                self.layoutIfNeeded()
            }
        )
    }

    private func updateUnderlinePosition() {
        guard let selectedButtonIndex = modernButtons.firstIndex(where: { $0.menuType == selectedMenu }) else { return }

        let selectedButton = modernButtons[selectedButtonIndex]
        let buttonCenterX = selectedButton.frame.midX
        underlineLeadingConstraint.constant = buttonCenterX - (Constants.underlineWidth / 2)
    }
}
