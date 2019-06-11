import Foundation

class DiscoverTableConfigurator {
    func configure(view: DiscoverTableViewController) {
        let presenter = DiscoverPresenter()
        presenter.view = view
        
        view.output = presenter
    }
}
