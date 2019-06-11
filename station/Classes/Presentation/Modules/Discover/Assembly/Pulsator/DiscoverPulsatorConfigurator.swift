import Foundation

class DiscoverPulsatorConfigurator {
    func configure(view: DiscoverPulsatorViewController) {
        let presenter = DiscoverPresenter()
        presenter.view = view
        
        view.output = presenter
    }
}
