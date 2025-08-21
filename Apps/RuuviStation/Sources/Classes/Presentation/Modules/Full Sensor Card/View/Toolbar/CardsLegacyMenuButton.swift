import UIKit
import RuuviOntology
import RuuviLocalization

final class CardsLegacyMenuButton: UIButton {

    // MARK: - Properties
    let menuType: CardsLegacyMenuType
    private let iconImageView = UIImageView()
    private var currentSubType: CardsMenuType = .measurement {
        didSet {
            updateIcon()
        }
    }

    // MARK: - Constants
    private enum Constants {
        static let iconSize: CGFloat = 34
        static let buttonWidth: CGFloat = 34
        static let animationDuration: Double = 0.5
        static let animationDelay: Double = 0.1
    }

    // MARK: - Initialization
    init(menuType: CardsLegacyMenuType) {
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
        updateIcon()
    }

    private func setupIconImageView() {
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

    // MARK: - Icon Management
    private func updateIcon() {
        if menuType == .measurementGraph {
            // Show the opposite icon - what will happen when tapped
            iconImageView.image = currentSubType == .measurement ?
            RuuviAsset.CardsMenu.iconGraphOld.image : CardsMenuType.measurement.icon
        } else {
            iconImageView.image = menuType.icon
        }
    }

    func setCurrentSubType(_ subType: CardsMenuType) {
        currentSubType = subType
    }

    // MARK: - Alert State Management
    func updateAlertState(for snapshot: RuuviTagCardSnapshot?) {
        iconImageView.layer.removeAllAnimations()

        guard let snapshot = snapshot,
              snapshot.metadata.isAlertAvailable else {
            iconImageView.image = nil
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
        if isAlertAvailable {
            isUserInteractionEnabled = true
            iconImageView.image = RuuviAsset.CardsMenu.iconAlertsOff.image
            iconImageView.tintColor = .white
            removeAlertAnimations(alpha: 0.5)
        }
    }

    private func configureForRegisteredState() {
        isUserInteractionEnabled = true
        iconImageView.image = RuuviAsset.CardsMenu.iconAlerts.image
        iconImageView.tintColor = .white
        removeAlertAnimations(alpha: 1.0)
    }

    private func configureForFiringState() {
        isUserInteractionEnabled = true
        iconImageView.image = RuuviAsset.CardsMenu.iconAlertsActive.image
        iconImageView.tintColor = RuuviColor.orangeColor.color
        iconImageView.alpha = 1.0
        startAlertAnimation()
    }

    // MARK: - Animation Management
    private func startAlertAnimation() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDelay) { [weak self] in
            UIView.animate(
                withDuration: Constants.animationDuration,
                delay: 0,
                options: [.repeat, .autoreverse, .beginFromCurrentState],
                animations: {
                    self?.iconImageView.alpha = 0.0
                }
            )
        }
    }

    private func removeAlertAnimations(alpha: Double = 1.0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.animationDelay) { [weak self] in
            self?.iconImageView.layer.removeAllAnimations()
            self?.iconImageView.alpha = alpha
        }
    }
}
