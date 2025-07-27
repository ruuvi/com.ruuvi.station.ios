import Foundation
import RuuviOntology

protocol NewCardsBaseViewOutput: AnyObject {
    func viewWillAppear()
    func viewDidChangeTab(_ tab: CardsMenuType)
    func viewDidNavigateToSnapshot(at index: Int)
}
