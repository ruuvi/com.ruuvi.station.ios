import Foundation
import RuuviOntology

enum GraphHistoryAbortSyncSource {
    case rootBackButton
    case rootNavigationButton(Int) // Target Index
    case topMenuSwitch
    case inPageCancel
}

protocol CardsGraphPresenterInput: CardsPresenterInput {
    func start(shouldSyncFromCloud: Bool)
    func configure(output: CardsGraphPresenterOutput?)
    func scroll(to measurementType: MeasurementType)
    func showAbortSyncConfirmationDialog(
        for snapshot: RuuviTagCardSnapshot,
        from source: GraphHistoryAbortSyncSource
    )
    func reloadChartsData(shouldSyncFromCloud: Bool)
}
