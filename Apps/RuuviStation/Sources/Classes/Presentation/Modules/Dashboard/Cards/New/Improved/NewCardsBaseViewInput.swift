import Foundation
import RuuviOntology

protocol NewCardsBaseViewInput: AnyObject {
    func setActiveTab(_ tab: CardsMenuType)
    func setSnapshots(_ snapshots: [RuuviTagCardSnapshot])
    func setActiveSnapshot(_ snapshot: RuuviTagCardSnapshot)
    func setActiveSnapshotIndex(_ index: Int)
}
