import RuuviOntology
import Foundation

class CardsAlertsPresenter: NSObject, CardsAlertsViewOutput, CardsAlertsPresenterInput {
    func configure(
        with snapshots: [RuuviTagCardSnapshot],
        snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?
    ) {}
    func configure(
        with snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?
    ) {}
    func start() {}
    func stop() {}
    func scroll(to index: Int, animated: Bool) {}

    weak var view: CardsAlertsViewInput?
}
