import Foundation
import RuuviOntology

enum GraphHistoryAbortSyncSource {
    case rootBackButton
    case rootNavigationButton(Int) // Target Index
    case topMenuSwitch
    case inPageCancel
}

protocol CardsGraphPresenterInput: CardsPresenterInput {
    func configure(sensorSettings: SensorSettings?)
    func configure(output: CardsGraphPresenterOutput?)
    func showAbortSyncConfirmationDialog(
        for snapshot: RuuviTagCardSnapshot,
        from source: GraphHistoryAbortSyncSource
    )
    func reloadChartsData()
}
