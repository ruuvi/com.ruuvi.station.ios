import UIKit
import RuuviOntology

// MARK: - Graph View Controller
final class CardsGraphViewController: UIViewController, CardsGraphViewInput {

    // MARK: - Properties
    var output: CardsGraphViewOutput?

    // MARK: - UI Components
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Graph"
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

    private lazy var timeRangeButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("1 Day", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(timeRangeButtonTapped), for: .touchUpInside)
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        output?.graphViewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        output?.graphViewDidBecomeActive()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .clear

        view.addSubview(titleLabel)
        view.addSubview(snapshotLabel)
        view.addSubview(timeRangeButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            snapshotLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            snapshotLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            snapshotLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            timeRangeButton.topAnchor.constraint(equalTo: snapshotLabel.bottomAnchor, constant: 30),
            timeRangeButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timeRangeButton.widthAnchor.constraint(equalToConstant: 200),
            timeRangeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Actions
    @objc private func timeRangeButtonTapped() {
        output?.graphViewDidSelectTimeRange(.day1)
    }

    // MARK: - CardsGraphViewInput
    func showSelectedSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        DispatchQueue.main.async { [weak self] in
            if let snapshot = snapshot {
                self?.snapshotLabel.text = "Graph for: \(snapshot.displayData.name)\nConnection: \(snapshot.connectionData.isConnected ? "Connected" : "Disconnected")"
            } else {
                self?.snapshotLabel.text = "No sensor selected"
            }
        }
    }

    func updateGraphData() {
        print("Updating graph data...")
    }
}
