import Foundation

protocol SensorRemovalViewInput: ViewInput {
    func updateView(claimedAndOwned: Bool, locallyOwned: Bool, shared: Bool)
    func showHistoryDataRemovalConfirmationDialog()
}
