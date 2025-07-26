import Foundation
import RuuviOntology

protocol NewCardsBaseViewOutput: AnyObject {
    func viewDidChangeTab(_ tab: CardsMenuType)
    func viewDidNavigateTo(_ snapshot: RuuviTagCardSnapshot)
}
