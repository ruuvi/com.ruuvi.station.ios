import Foundation

protocol CardsMeasurementViewInput: AnyObject {
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot], currentIndex: Int)
    func navigateToIndex(_ index: Int, animated: Bool)
}
