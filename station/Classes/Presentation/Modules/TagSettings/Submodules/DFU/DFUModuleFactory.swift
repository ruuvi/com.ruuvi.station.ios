import UIKit
import RuuviOntology
import RuuviDFU
import BTKit
import RuuviPool
import RuuviStorage
import RuuviLocal
import RuuviDaemon
import RuuviPresenters
import RuuviPersistence

protocol DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput
}

final class DFUModuleFactoryImpl: DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput {
        let r = AppAssembly.shared.assembler.resolver
        let interactor = DFUInteractor()
        interactor.ruuviDFU = r.resolve(RuuviDFU.self)
        interactor.background = r.resolve(BTBackground.self)
        let foreground = r.resolve(BTForeground.self)!
        let idPersistence = r.resolve(RuuviLocalIDs.self)!
        let realmPersistence = r.resolve(RuuviPersistence.self, name: "realm")!
        let sqiltePersistence = r.resolve(RuuviPersistence.self, name: "sqlite")!
        let ruuviPool = r.resolve(RuuviPool.self)!
        let ruuviStorage = r.resolve(RuuviStorage.self)!
        let settings = r.resolve(RuuviLocalSettings.self)!
        let propertiesDaemon = r.resolve(RuuviTagPropertiesDaemon.self)!
        let activityPresenter = r.resolve(ActivityPresenter.self)!
        let presenter = DFUPresenter(
            interactor: interactor,
            ruuviTag: ruuviTag,
            foreground: foreground,
            idPersistence: idPersistence,
            realmPersistence: realmPersistence,
            sqiltePersistence: sqiltePersistence,
            ruuviPool: ruuviPool,
            ruuviStorage: ruuviStorage,
            settings: settings,
            propertiesDaemon: propertiesDaemon,
            activityPresenter: activityPresenter
        )
        return presenter
    }
}
