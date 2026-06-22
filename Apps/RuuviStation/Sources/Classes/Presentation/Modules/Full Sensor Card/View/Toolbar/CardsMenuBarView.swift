import UIKit
import RuuviOntology

final class CardsMenuBarView: UIView {

    // MARK: - Properties
    private let stackView = UIStackView()
    private let underlineView = UIView()
    private var buttons: [CardsMenuButton] = []
    private var underlineLeadingConstraint: NSLayoutConstraint!
    private var selectedMenu: CardsMenuType = .measurement
    private var hasAppeared = false
    private let showsAlertBadge: Bool

    // MARK: - Constants
    private enum Constants {
        static let stackSpacing: CGFloat = 2
        static let buttonSize: CGFloat = 40
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
    init(showsAlertBadge: Bool) {
        self.showsAlertBadge = showsAlertBadge
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

        updateSelection(animated: animated)

        if notify {
            onTabChanged?(tab)
        }
    }

    func getCurrentTab() -> CardsMenuType {
        return selectedMenu
    }

    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        buttons.first(where: { $0.menuType == .alerts })?.updateAlertState(for: snapshot)
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        guard bounds.width > 0 else { return }

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

        setupUIContent()

        setupStackView()
        setupConstraints()
    }

    private func setupUIContent() {
        createButtons()
        setupUnderlineView()
        addSubview(stackView)
        addSubview(underlineView)
    }

    private func createButtons() {
        buttons = CardsMenuType.allCases.map { menuType in
            let button = CardsMenuButton(
                menuType: menuType,
                showsAlertBadge: showsAlertBadge
            )
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            button.size(width: Constants.buttonSize, height: Constants.buttonSize)
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
        stackView.distribution = .fill
        stackView.alignment = .center
        stackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func setupConstraints() {
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

    // MARK: - Button Actions
    @objc private func buttonTapped(_ sender: CardsMenuButton) {
        guard sender.menuType != selectedMenu else { return }
        selectedMenu = sender.menuType
        updateSelection(animated: true)
        onTabChanged?(selectedMenu)
    }

    // MARK: - Selection Updates
    private func updateSelection(animated: Bool) {
        guard let selectedButtonIndex = buttons.firstIndex(where: {
                  $0.menuType == selectedMenu
              }) else { return }

        layoutIfNeeded()
        stackView.layoutIfNeeded()
        let selectedButton = buttons[selectedButtonIndex]

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
        guard let selectedButtonIndex = buttons.firstIndex(where: { $0.menuType == selectedMenu }) else { return }

        stackView.layoutIfNeeded()
        let selectedButton = buttons[selectedButtonIndex]
        let buttonCenterX = selectedButton.frame.midX
        underlineLeadingConstraint.constant = buttonCenterX - (Constants.underlineWidth / 2)
    }
}
