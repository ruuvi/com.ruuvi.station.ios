import UIKit
import RuuviOntology
import RuuviDFU
import BTKit
import RuuviPool

protocol DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput
}

final class DFUModuleFactoryImpl: DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput {
        let r = AppAssembly.shared.assembler.resolver
        let interactor = DFUInteractor()
        interactor.ruuviDFU = r.resolve(RuuviDFU.self)
        interactor.background = r.resolve(BTBackground.self)
        let ruuviPool = r.resolve(RuuviPool.self)!
        let presenter = DFUPresenter(
            interactor: interactor,
            ruuviTag: ruuviTag,
            ruuviPool: ruuviPool
        )
        return presenter
    }
}
