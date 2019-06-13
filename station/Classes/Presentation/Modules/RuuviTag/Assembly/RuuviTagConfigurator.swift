import Foundation

class RuuviTagConfigurator {
    func configure(view: RuuviTagViewController) {
        let presenter = RuuviTagPresenter()
        presenter.view = view
        
        view.output = presenter
    }
}
