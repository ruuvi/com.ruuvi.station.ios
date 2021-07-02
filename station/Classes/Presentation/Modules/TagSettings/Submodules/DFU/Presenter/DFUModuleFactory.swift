import UIKit
import RuuviOntology

protocol DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput
}

final class DFUModuleFactoryImpl: DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput {
        let interactor = DFUInteractor()
        let presenter = DFUPresenter(
            interactor: interactor,
            ruuviTag: ruuviTag
        )
        return presenter
    }
}
