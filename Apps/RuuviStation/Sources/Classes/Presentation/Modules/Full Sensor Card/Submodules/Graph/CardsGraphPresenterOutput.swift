import Foundation

protocol CardsGraphPresenterOutput: AnyObject {
    func setGraphGattSyncInProgress(_ inProgress: Bool)
    func graphGattSyncAborted(
        for snapshot: RuuviTagCardSnapshot,
        source: GraphHistoryAbortSyncSource
    )
}
