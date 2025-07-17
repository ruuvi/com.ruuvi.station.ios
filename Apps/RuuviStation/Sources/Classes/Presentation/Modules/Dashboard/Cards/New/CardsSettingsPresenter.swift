import UIKit
import RuuviLocal
import RuuviOntology

// MARK: - Settings Presenter
final class CardsSettingsPresenter: CardsSettingsViewOutput {

    // MARK: - Properties
    weak var view: CardsSettingsViewInput?

    // MARK: - Services
    private let dataService: RuuviTagDataService
    private let settings: RuuviLocalSettings

    // MARK: - State
    private var currentSnapshot: RuuviTagCardSnapshot?

    // MARK: - Initialization
    init(
        dataService: RuuviTagDataService,
        settings: RuuviLocalSettings
    ) {
        self.dataService = dataService
        self.settings = settings
    }

    // MARK: - Public Methods
    func updateCurrentSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        currentSnapshot = snapshot
        view?.showSelectedSnapshot(snapshot)
    }

    // MARK: - CardsSettingsViewOutput
    func settingsViewDidLoad() {
        view?.showSelectedSnapshot(currentSnapshot)
    }

    func settingsViewDidBecomeActive() {
        view?.updateSettingsData()
        view?.showSelectedSnapshot(currentSnapshot)
    }

    func settingsViewDidUpdateSensorName(_ name: String) {
        print("Updating sensor name to: \(name)")

        guard let snapshot = currentSnapshot else { return }

        // Update sensor name via data service
        dataService.snapshotSensorNameDidChange(to: name, for: snapshot)

        view?.updateSettingsData()
    }
}
