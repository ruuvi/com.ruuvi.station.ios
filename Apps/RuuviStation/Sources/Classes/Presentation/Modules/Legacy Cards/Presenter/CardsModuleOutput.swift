import Foundation
import RuuviOntology

protocol LegacyCardsModuleOutput: AnyObject {
    func cardsViewDidRefresh(module: CardsModuleInput)
    func cardsViewDidDismiss(module: CardsModuleInput)
}
