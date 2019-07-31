import Foundation
import CoreLocation

class LocationPickerPresenter: LocationPickerModuleInput {
    weak var view: LocationPickerViewInput!
    var router: LocationPickerRouterInput!
    var locationService: LocationService!
    var activityPresenter: ActivityPresenter!
    var errorPresenter: ErrorPresenter!
    var permissionsManager: PermissionsManager!
    var permissionPresenter: PermissionPresenter!
    var locationManager: LocationManager!
    
    private var isLoading: Bool = false {
        didSet {
            if isLoading != oldValue {
                if isLoading {
                    activityPresenter.increment()
                } else {
                    activityPresenter.decrement()
                }
            }
        }
    }
    private weak var output: LocationPickerModuleOutput?
    
    func configure(output: LocationPickerModuleOutput) {
        self.output = output
    }
}

extension LocationPickerPresenter: LocationPickerViewOutput {
    func viewDidTriggerCancel() {
        router.dismiss()
    }
    
    func viewDidTriggerDone() {
        if let location = view.selectedLocation {
            output?.locationPicker(module: self, didPick: location)
        }
        router.dismiss()
    }
    
    func viewDidEnterSearchQuery(_ query: String) {
        let search = locationService.search(query: query)
        isLoading = true
        search.on(success: { [weak self] (locations) in
            self?.view.selectedLocation = locations.first
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        }) {
            self.isLoading = false
        }
    }
    
    func viewDidLongPressOnMap(at coordinate: CLLocationCoordinate2D) {
        let reverseGeoCode = locationService.reverseGeocode(coordinate: coordinate)
        reverseGeoCode.on(success: { [weak self] (locations) in
            self?.view.selectedLocation = locations.last
        }, failure: { [weak self] (error) in
            self?.errorPresenter.present(error: error)
        })
    }
    
    func viewDidTriggerCurrentLocation() {
        if !permissionsManager.isLocationPermissionGranted {
            permissionsManager.requestLocationPermission { [weak self] (granted) in
                if granted {
                    self?.obtainCurrentLocation()
                } else {
                    self?.permissionPresenter.presentNoLocationPermission()
                }
            }
        } else {
            obtainCurrentLocation()
        }
    }
    
    private func obtainCurrentLocation() {
        locationManager.getCurrentLocation { [weak self] (location) in
            if let location = location {
                let reverseGeoCode = self?.locationService.reverseGeocode(coordinate: location.coordinate)
                reverseGeoCode?.on(success: { (locations) in
                    self?.view.selectedLocation = locations.last
                }, failure: { (error) in
                    self?.errorPresenter.present(error: error)
                })
            }
        }
    }

}
