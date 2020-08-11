import Foundation

final class TagChartAssembler {
    static func createModule() -> TagChartModuleInput {
        let r = AppAssembly.shared.assembler.resolver
        let view = TagChartView(frame: .zero)
        let presenter = TagChartPresenter()
        presenter.settings = r.resolve(Settings.self)
        presenter.calibrationService = r.resolve(CalibrationService.self)
        presenter.view = view

        view.presenter = presenter
        return presenter
    }
}
