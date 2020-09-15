import Foundation

class SelectionPresenter {
    weak var view: SelectionViewInput!
    var router: SelectionRouterInput!
    private var items: [SelectionItemProtocol] = [] {
        didSet {
            view.items = items
        }
    }
    var output: SelectionModuleOutput?
}
extension SelectionPresenter: SelectionModuleInput {
    func configure(dataSource: [SelectionItemProtocol], output: SelectionModuleOutput?) {
        self.items = dataSource
        self.output = output
    }

    func dismiss() {
        router.dismiss()
    }
}

extension SelectionPresenter: SelectionViewOutput {
    func viewDidSelect(itemAtIndex index: Int) {
        output?.selection(module: self, didSelectItem: items[index])
    }
}
