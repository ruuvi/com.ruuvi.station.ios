import RuuviOntology
import Foundation

protocol CardsPresenterInput: AnyObject {
    func configure(
        with snapshots: [RuuviTagCardSnapshot],
        snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        settings: SensorSettings?
    )
    func configure(
        with snapshot: RuuviTagCardSnapshot,
        sensor: AnyRuuviTagSensor?,
        settings: SensorSettings?
    )
    func start()
    func stop()
    func scroll(to index: Int, animated: Bool)
}
