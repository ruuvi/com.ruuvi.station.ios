import UIKit
import RuuviOntology
import RuuviLocalization

final class CardsMenuButton: UIButton {

    // MARK: - Properties
    let menuType: CardsMenuType
    private let iconImageView = UIImageView()

    // MARK: - Constants
    private enum Constants {
        static let iconSize: CGFloat = 30
        static let buttonWidth: CGFloat = 34
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
        iconImageView.image = menuType.icon
        iconImageView.tintColor = .white
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(iconImageView)
    }

    private func setupButton() {
        backgroundColor = .clear
        widthAnchor.constraint(equalToConstant: Constants.buttonWidth).isActive = true
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: Constants.iconSize),
            iconImageView.heightAnchor.constraint(equalToConstant: Constants.iconSize),
        ])
    }

    // MARK: - Alert State Management
    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        iconImageView.layer.removeAllAnimations()

        guard let snapshot = snapshot,
              snapshot.metadata.isAlertAvailable else {
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
    }

    private func configureForEmptyState(isAlertAvailable: Bool) {
        iconImageView.tintColor = .white
        if isAlertAvailable {
            isUserInteractionEnabled = true
            iconImageView.alpha = 1
        } else {
            iconImageView.alpha = 0.5
        }
    }

    private func configureForRegisteredState() {
        isUserInteractionEnabled = true
        iconImageView.tintColor = .white
        iconImageView.alpha = 1.0
    }

    private func configureForFiringState() {
        isUserInteractionEnabled = true
        iconImageView.tintColor = RuuviColor.orangeColor.color
        iconImageView.alpha = 1.0
    }
}
