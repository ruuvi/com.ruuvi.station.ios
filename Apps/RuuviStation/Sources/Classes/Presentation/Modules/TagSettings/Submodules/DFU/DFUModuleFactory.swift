import BTKit
import RuuviDaemon
import RuuviDFU
import RuuviLocal
import RuuviOntology
import RuuviPersistence
import RuuviPool
import RuuviPresenters
import RuuviStorage
import UIKit

protocol DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput
}

final class DFUModuleFactoryImpl: DFUModuleFactory {
    func create(for ruuviTag: RuuviTagSensor) -> DFUModuleInput {
        let r = AppAssembly.shared.assembler.resolver
        let firmwareVersion = RuuviDataFormat.dataFormat(
            from: ruuviTag.version
        )
        let dfuDeviceType: RuuviDeviceType =
            firmwareVersion == .e1 || firmwareVersion == .v6 ? .ruuviAir : .ruuviTag
        let flags = r.resolve(RuuviLocalFlags.self)
        var firmwareType: RuuviDFUFirmwareType = .latest
        if let flags = flags {
            if flags.downloadBetaFirmware {
                firmwareType = .beta
            }
            if flags.downloadAlphaFirmware {
                firmwareType = .alpha
            }
        }

        let interactor = DFUInteractor(
            deviceType: dfuDeviceType,
            firmwareType: firmwareType
        )
        interactor.ruuviDFU = r.resolve(RuuviDFU.self)
        interactor.background = r.resolve(BTBackground.self)
        let foreground = r.resolve(BTForeground.self)!
        let idPersistence = r.resolve(RuuviLocalIDs.self)!
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
