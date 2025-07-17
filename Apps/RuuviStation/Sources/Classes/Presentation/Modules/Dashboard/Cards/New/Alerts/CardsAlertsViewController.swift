import UIKit
import RuuviOntology

// MARK: - Alerts View Controller
final class CardsAlertsViewController: UIViewController, CardsAlertsViewInput {

    // MARK: - Properties
    var output: CardsAlertsViewOutput?

    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Alerts"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var snapshotLabel: UILabel = {
        let label = UILabel()
        label.text = "No sensor selected"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var alertToggleButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Toggle Temperature Alert", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(alertToggleButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - State
    private var temperatureAlertEnabled = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        output?.alertsViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.alertsViewDidBecomeActive()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear

        view.addSubview(titleLabel)
        view.addSubview(snapshotLabel)
        view.addSubview(alertToggleButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            snapshotLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            snapshotLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            snapshotLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            alertToggleButton.topAnchor.constraint(equalTo: snapshotLabel.bottomAnchor, constant: 30),
            alertToggleButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            alertToggleButton.widthAnchor.constraint(equalToConstant: 200),
            alertToggleButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Actions
    @objc private func alertToggleButtonTapped() {
        temperatureAlertEnabled.toggle()
        output?.alertsViewDidToggleAlert(.temperature, isOn: temperatureAlertEnabled)

        let title = temperatureAlertEnabled ? "Disable Temperature Alert" : "Enable Temperature Alert"
        alertToggleButton.setTitle(title, for: .normal)
    }

    // MARK: - CardsAlertsViewInput
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        DispatchQueue.main.async { [weak self] in
            if let snapshot = snapshot {
                let alertCount = snapshot.displayData.indicatorGrid?.indicators.filter { $0.alertConfig.isActive }.count ?? 0
                self?.snapshotLabel.text = "Alerts for: \(snapshot.displayData.name)\nActive alerts: \(alertCount)"
            } else {
                self?.snapshotLabel.text = "No sensor selected"
            }
        }
    }

    func updateAlertsData() {
        print("Updating alerts data...")
    }
}
