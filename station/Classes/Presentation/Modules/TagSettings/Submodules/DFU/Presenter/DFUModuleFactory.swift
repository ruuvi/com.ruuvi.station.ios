import UIKit
import RuuviOntology
import RuuviDFU
import BTKit

protocol DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput
}

final class DFUModuleFactoryImpl: DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput {
        let r = AppAssembly.shared.assembler.resolver
        let interactor = DFUInteractor()
        interactor.ruuviDFU = r.resolve(RuuviDFU.self)
        interactor.background = r.resolve(BTBackground.self)
        let presenter = DFUPresenter(
            interactor: interactor,
            ruuviTag: ruuviTag
        )
        return presenter
    }
}
