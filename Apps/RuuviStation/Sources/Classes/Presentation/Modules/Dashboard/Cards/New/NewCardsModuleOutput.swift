import Foundation
import RuuviOntology

protocol NewCardsModuleOutput: AnyObject {
    func cardsViewDidRefresh(module: NewCardsModuleInput)
    func cardsViewDidDismiss(module: NewCardsModuleInput)

    func tagChartSafeToClose(
        module: NewCardsModuleInput,
        dismissParent: Bool
    )
    func tagChartSafeToSwipe(
        to ruuviTag: AnyRuuviTagSensor, module: NewCardsModuleInput
    )
}
