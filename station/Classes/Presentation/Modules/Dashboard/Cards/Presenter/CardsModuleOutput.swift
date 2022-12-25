import Foundation
import RuuviOntology

protocol CardsModuleOutput: AnyObject {
    func cardsViewDidRefresh(module: CardsModuleInput)
    func cardsViewDidDismiss(module: CardsModuleInput)
}
