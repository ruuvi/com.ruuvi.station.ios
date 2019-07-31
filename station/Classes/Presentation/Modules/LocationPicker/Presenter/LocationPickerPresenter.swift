import Foundation

class LocationPickerPresenter: LocationPickerModuleInput {
    weak var view: LocationPickerViewInput!
    var router: LocationPickerRouterInput!
}

extension LocationPickerPresenter: LocationPickerViewOutput {
    
}
