import Foundation
import RuuviOntology
import UIKit

// MARK: - Main Landing View Protocol
protocol CardsLandingViewInput: AnyObject {
    var isRefreshing: Bool { get set }
    func updateSnapshots(_ snapshots: [RuuviTagCardSnapshot])
    func updateCurrentSnapshotIndex(_ index: Int)
    func updateCurrentTab(_ tab: CardsMenuType)
    func showBluetoothDisabled(userDeclined: Bool)
}
