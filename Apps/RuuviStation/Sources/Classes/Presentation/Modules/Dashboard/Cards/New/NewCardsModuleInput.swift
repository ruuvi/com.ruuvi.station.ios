import Foundation
import RuuviOntology

protocol NewCardsModuleInput: AnyObject {
    func dismiss(completion: (() -> Void)?)
}

extension NewCardsModuleInput {
    func dismiss() {
        dismiss(completion: nil)
    }
}
