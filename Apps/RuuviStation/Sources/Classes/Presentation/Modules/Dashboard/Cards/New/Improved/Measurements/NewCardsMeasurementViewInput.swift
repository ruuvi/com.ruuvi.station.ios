import Foundation

protocol NewCardsMeasurementViewInput: AnyObject {
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], currentIndex: Int)
//    func updateSnapshot(_ snapshot: RuuviTagCardSnapshot)
    func navigateToIndex(_ index: Int, animated: Bool)
}
