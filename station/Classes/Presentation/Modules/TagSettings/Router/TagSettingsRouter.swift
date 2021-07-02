import UIKit
import LightRoute
import SwiftUI
import RuuviOntology

class TagSettingsRouter: TagSettingsRouterInput {
    weak var transitionHandler: UIViewController!

    func dismiss(completion: (() -> Void)?) {
        try! transitionHandler.closeCurrentModule().perform()
        completion?()
    }

    func openShare(for sensor: RuuviTagSensor) {
        let restorationId = "ShareViewController"
        let factory = StoryboardFactory(storyboardName: "Share", bundle: .main, restorationId: restorationId)
        try! transitionHandler
            .forStoryboard(factory: factory,
                           to: ShareModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(sensor: sensor)
            })
    }

    func openOffsetCorrection(type: OffsetCorrectionType,
                              ruuviTag: RuuviTagSensor,
                              sensorSettings: SensorSettings?) {
        let factory = StoryboardFactory(storyboardName: "OffsetCorrection")
        try! transitionHandler
            .forStoryboard(factory: factory, to: OffsetCorrectionModuleInput.self)
            .to(preferred: .navigation(style: .push))
            .then({ (module) -> Any? in
                module.configure(type: type, ruuviTag: ruuviTag, sensorSettings: sensorSettings)
            })
    }

    func openUpdateFirmware(ruuviTag: RuuviTagSensor) {
        let factory = DFUModuleFactoryImpl()
        let module = factory.create(for: ruuviTag)
        transitionHandler
            .navigationController?
            .pushViewController(
                module.viewController,
                animated: true
            )
    }

    func macCatalystExportFile(with path: URL, delegate: UIDocumentPickerDelegate?) {
        let controller = UIDocumentPickerViewController(url: path, in: .exportToService)
        controller.delegate = delegate
        transitionHandler.present(controller, animated: true)
    }
}
