import RuuviLocal
import RuuviService
import UIKit

protocol RuuviCloudModuleFactory {
    func create() -> RuuviCloudModuleInput
}

final class RuuviCloudModuleFactoryImpl: RuuviCloudModuleFactory {
    func create() -> RuuviCloudModuleInput {
        let r = AppAssembly.shared.assembler.resolver

        let presenter = RuuviCloudPresenter()
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.ruuviAppSettingsService = r.resolve(RuuviServiceAppSettings.self)
        return presenter
    }
}
