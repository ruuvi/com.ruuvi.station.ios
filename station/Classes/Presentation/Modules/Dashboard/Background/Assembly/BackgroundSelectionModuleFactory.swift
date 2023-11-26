import UIKit
import RuuviOntology
import RuuviService
import RuuviPresenters
import RuuviLocal

protocol BackgroundSelectionModuleFactory {
    func create(for ruuviTag: RuuviTagSensor?) -> BackgroundSelectionModuleInput
}

final class BackgroundSelectionModuleFactoryImpl: BackgroundSelectionModuleFactory {
    func create(for ruuviTag: RuuviTagSensor?) -> BackgroundSelectionModuleInput {
        let r = AppAssembly.shared.assembler.resolver

        let presenter = BackgroundSelectionPresenter(
            ruuviTag: ruuviTag
        )
        presenter.photoPickerPresenter = r.resolve(PhotoPickerPresenter.self)
        presenter.ruuviSensorPropertiesService = r.resolve(RuuviServiceSensorProperties.self)
        presenter.ruuviLocalImages = r.resolve(RuuviLocalImages.self)
        presenter.errorPresenter = r.resolve(ErrorPresenter.self)
        return presenter
    }
}
