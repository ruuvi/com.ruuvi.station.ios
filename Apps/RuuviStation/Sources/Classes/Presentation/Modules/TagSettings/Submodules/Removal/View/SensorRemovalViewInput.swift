import Foundation
import RuuviOntology

protocol SensorRemovalViewInput: ViewInput {
    func updateView(ownership: SensorOwnership)
    func showHistoryDataRemovalConfirmationDialog()
}
