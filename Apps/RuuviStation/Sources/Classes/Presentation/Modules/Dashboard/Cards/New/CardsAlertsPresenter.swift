import UIKit
import RuuviLocal
import RuuviOntology

// MARK: - Alerts Presenter
final class CardsAlertsPresenter: CardsAlertsViewOutput {

    // MARK: - Properties
    weak var view: CardsAlertsViewInput?

    // MARK: - Services
    private let alertService: RuuviTagAlertService
    private let settings: RuuviLocalSettings

    // MARK: - State
    private var currentSnapshot: RuuviTagCardSnapshot?

    // MARK: - Initialization
    init(
        alertService: RuuviTagAlertService,
        settings: RuuviLocalSettings
    ) {
        self.alertService = alertService
        self.settings = settings
    }

    // MARK: - Public Methods
    func updateCurrentSnapshot(_ snapshot: RuuviTagCardSnapshot?) {
        currentSnapshot = snapshot
        view?.showSelectedSnapshot(snapshot)
    }

    // MARK: - CardsAlertsViewOutput
    func alertsViewDidLoad() {
        view?.showSelectedSnapshot(currentSnapshot)
    }

    func alertsViewDidBecomeActive() {
        view?.updateAlertsData()
        view?.showSelectedSnapshot(currentSnapshot)
    }

    func alertsViewDidToggleAlert(_ type: MeasurementType, isOn: Bool) {
        print("Alert toggle for \(type): \(isOn)")

        guard let snapshot = currentSnapshot else { return }

        // TODO: Update alert configuration
        // This would typically:
        // - Update alert service with new state
        // - Save alert preferences
        // - Update UI to reflect changes

        alertService.updateAlertForMeasurement(
            snapshot: snapshot,
            type: type,
            isOn: isOn,
            alertState: isOn ? .registered : .empty,
            mutedTill: nil
        )

        view?.updateAlertsData()
    }
}
