import UIKit
import RuuviOntology

// MARK: - Settings View Controller
final class CardsSettingsViewController: UIViewController, CardsSettingsViewInput {

    // MARK: - Properties
    var output: CardsSettingsViewOutput?

    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Settings"
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

    private lazy var nameUpdateButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Update Sensor Name", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(nameUpdateButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        output?.settingsViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.settingsViewDidBecomeActive()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear

        view.addSubview(titleLabel)
        view.addSubview(snapshotLabel)
        view.addSubview(nameUpdateButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            snapshotLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            snapshotLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            snapshotLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            nameUpdateButton.topAnchor.constraint(equalTo: snapshotLabel.bottomAnchor, constant: 30),
            nameUpdateButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameUpdateButton.widthAnchor.constraint(equalToConstant: 200),
            nameUpdateButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Actions
    @objc private func nameUpdateButtonTapped() {
        let alert = UIAlertController(title: "Update Name", message: "Enter new sensor name", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Sensor name"
        }

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Update", style: .default) { [weak self] _ in
            if let newName = alert.textFields?.first?.text, !newName.isEmpty {
                self?.output?.settingsViewDidUpdateSensorName(newName)
            }
        })

        present(alert, animated: true)
    }

    // MARK: - CardsSettingsViewInput
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        DispatchQueue.main.async { [weak self] in
            if let snapshot = snapshot {
                self?.snapshotLabel.text = "Settings for: \(snapshot.displayData.name)\nVersion: \(snapshot.displayData.version ?? 0)\nCloud: \(snapshot.metadata.isCloud ? "Yes" : "No")"
            } else {
                self?.snapshotLabel.text = "No sensor selected"
            }
        }
    }

    func updateSettingsData() {
        print("Updating settings data...")
    }
}
