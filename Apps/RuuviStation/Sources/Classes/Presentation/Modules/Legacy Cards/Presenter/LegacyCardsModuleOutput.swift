import Foundation
import RuuviOntology

protocol LegacyCardsModuleOutput: AnyObject {
    func cardsViewDidRefresh(module: LegacyCardsModuleInput)
    func cardsViewDidDismiss(module: LegacyCardsModuleInput)
}
