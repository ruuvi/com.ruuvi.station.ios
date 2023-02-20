import UIKit
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal

protocol DevicesModuleFactory {
    func create() -> DevicesModuleInput
}

final class DevicesModuleFactoryImpl: DevicesModuleFactory {
    func create() -> DevicesModuleInput {
        let r = AppAssembly.shared.assembler.resolver

        let interactor = DevicesInteractor()

        let presenter = DevicesPresenter()
        presenter.interactor = interactor
        interactor.ruuviServiceCloudNotification = r.resolve(RuuviServiceCloudNotification.self)
        interactor.presenter = presenter

        return presenter
    }
}
