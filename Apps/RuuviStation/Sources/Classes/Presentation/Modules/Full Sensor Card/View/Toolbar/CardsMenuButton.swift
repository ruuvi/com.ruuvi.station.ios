import UIKit
import RuuviOntology
import RuuviLocalization

final class CardsMenuButton: UIButton {

    // MARK: - Properties
    let menuType: CardsMenuType
    private let iconImageView = UIImageView()
    private let alertBellButton = AlertBellButton()

    // MARK: - Constants
    private enum Constants {
        static let iconSize: CGFloat = 30
    }

    // MARK: - Initialization
    init(menuType: CardsMenuType) {
        self.menuType = menuType
        super.init(frame: .zero)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupUI() {
        setupIconImageView()
        setupButton()
        setupConstraints()
    }

    private func setupIconImageView() {
        guard menuType != .alerts else {
            alertBellButton.configureBell(
                image: menuType.icon,
                tintColor: .white,
                alpha: 1
            )
            alertBellButton.isUserInteractionEnabled = false
            addSubview(alertBellButton)
            return
        }

        iconImageView.image = menuType.icon
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
    }

    private func setupButton() {
        backgroundColor = .clear
    }

    private func setupConstraints() {
        if menuType == .alerts {
            alertBellButton.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                alertBellButton.topAnchor.constraint(equalTo: topAnchor),
                alertBellButton.leadingAnchor.constraint(equalTo: leadingAnchor),
                alertBellButton.bottomAnchor.constraint(equalTo: bottomAnchor),
                alertBellButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            ])
        } else {
            NSLayoutConstraint.activate([
                iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
                iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconImageView.widthAnchor.constraint(equalToConstant: Constants.iconSize),
                iconImageView.heightAnchor.constraint(equalToConstant: Constants.iconSize),
            ])
        }
    }

    // MARK: - Alert State Management
    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        alertBellButton.removeBellAnimations()

        guard let snapshot = snapshot,
              snapshot.metadata.isAlertAvailable else {
            alertBellButton.hideBadge()
            isUserInteractionEnabled = false
            return
        }

        switch snapshot.alertData.alertState {
        case .empty, .none:
            configureForEmptyState(isAlertAvailable: snapshot.metadata.isAlertAvailable)
        case .registered:
            configureForRegisteredState()
        case .firing:
            configureForFiringState()
        }
        updateAlertBadge(for: snapshot)
    }

    private func configureForEmptyState(isAlertAvailable: Bool) {
        alertBellButton.configureBell(
            image: menuType.icon,
            tintColor: .white,
            alpha: isAlertAvailable ? 1 : 0.5
        )
        if isAlertAvailable {
            isUserInteractionEnabled = true
        } else {
            isUserInteractionEnabled = false
        }
    }

    private func configureForRegisteredState() {
        isUserInteractionEnabled = true
        alertBellButton.configureBell(
            image: menuType.icon,
            tintColor: .white,
            alpha: 1
        )
    }

    private func configureForFiringState() {
        isUserInteractionEnabled = true
        alertBellButton.configureBell(
            image: menuType.icon,
            tintColor: .white,
            alpha: 1
        )
    }

    private func updateAlertBadge(for snapshot: RuuviTagCardSnapshot) {
        guard menuType == .alerts,
              let badgeData = snapshot.alertBadgeData() else {
            alertBellButton.hideBadge()
            return
        }

        alertBellButton.configureBadge(
            count: badgeData.count,
            isTriggered: badgeData.isTriggered,
            normalTextColor: .white
        )
    }
}
