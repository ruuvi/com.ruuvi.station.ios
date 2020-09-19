import Foundation

class SelectionPresenter {
    weak var view: SelectionViewInput!
    var router: SelectionRouterInput!
    private var viewModel: SelectionViewModel? {
        didSet {
            view.viewModel = viewModel
        }
    }
    var output: SelectionModuleOutput?
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
        guard let item = viewModel?.items[index] else {
            dismiss()
            return
        }
        output?.selection(module: self, didSelectItem: item)
    }
}
