import UIKit

class LocationPickerAppleConfigurator {
    func configure(view: LocationPickerAppleViewController) {
        let router = LocationPickerRouter()
        router.transitionHandler = view
        
        let presenter = LocationPickerPresenter()
        presenter.view = view
        presenter.router = router
        
        view.output = presenter
    }
}
