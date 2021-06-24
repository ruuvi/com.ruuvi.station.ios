import Foundation
import RuuviLocal
import RuuviService

final class TagChartAssembler {
    static func createModule() -> TagChartModuleInput {
        let r = AppAssembly.shared.assembler.resolver
        let view = TagChartView(frame: .zero)
        view.settings = r.resolve(RuuviLocalSettings.self)
        let presenter = TagChartPresenter()
        presenter.settings = r.resolve(RuuviLocalSettings.self)
        presenter.view = view
        presenter.measurementService = r.resolve(RuuviServiceMeasurement.self)

        view.presenter = presenter
        return presenter
    }
}
