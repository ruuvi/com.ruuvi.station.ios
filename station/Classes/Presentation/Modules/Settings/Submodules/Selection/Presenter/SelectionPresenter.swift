import Foundation
import RuuviLocal

class SelectionPresenter {
    weak var view: SelectionViewInput!
    var router: SelectionRouterInput!
    var settings: RuuviLocalSettings!
    private var viewModel: SelectionViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }
    var output: SelectionModuleOutput?
}
extension SelectionPresenter {
    func viewDidLoad() {
        view.temperatureUnit = settings.temperatureUnit
        view.humidityUnit = settings.humidityUnit
        view.pressureUnit = settings.pressureUnit
    }
}
extension SelectionPresenter: SelectionModuleInput {
    func configure(viewModel: SelectionViewModel, output: SelectionModuleOutput?) {
        self.viewModel = viewModel
        self.output = output
    }

    func dismiss() {
        router.dismiss()
    }
}

extension SelectionPresenter: SelectionViewOutput {
    func viewDidSelect(itemAtIndex index: Int) {
        guard let viewModel = viewModel,
        viewModel.items.count > 0 else {
            dismiss()
            return
        }
        output?.selection(module: self, didSelectItem: viewModel.items[index], type: viewModel.unitSettingsType)
    }
}
