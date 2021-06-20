import Foundation
import MapKit
import Future
import RuuviOntology

struct LocationApple: Location {
    var city: String?
    var country: String?
    var coordinate: CLLocationCoordinate2D
}

class LocationServiceApple: LocationService {

    var locationPersistence: LocationPersistence!

    func search(query: String) -> Future<[Location], RUError> {
        let promise = Promise<[Location], RUError>()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else {
                if let error = error {
                    promise.fail(error: .map(error))
                } else {
                    promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
                }
                return
            }
            var locations = [LocationApple]()
            for item in response.mapItems {
                locations.append(LocationApple(city: item.placemark.locality,
                                               country: item.placemark.country,
                                               coordinate: item.placemark.coordinate))
            }
            promise.succeed(value: locations)
        }
        return promise.future
    }

    func reverseGeocode(coordinate: CLLocationCoordinate2D) -> Future<[Location], RUError> {
        if let locations = locationPersistence.locations(for: coordinate) {
            let promise = Promise<[Location], RUError>()
            promise.succeed(value: locations)
            return promise.future
        } else {
            return getReverseGeocodeLocation(coordinate: coordinate).future
        }
    }
}
// MARK: - Private
extension LocationServiceApple {
    private func getReverseGeocodeLocation(coordinate: CLLocationCoordinate2D) -> Promise<[Location], RUError> {
        let promise = Promise<[Location], RUError>()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geoCoder = CLGeocoder()
        let handler: CLGeocodeCompletionHandler = { [weak self] (placemarks, error) in
            guard let placemarks = placemarks else {
                if let error = error {
                    promise.fail(error: .map(error))
                } else {
                    promise.fail(error: .unexpected(.callbackErrorAndResultAreNil))
                }
                return
            }

            var locations = [LocationApple]()
            for placemark in placemarks {
                locations.append(LocationApple(city: placemark.locality,
                                               country: placemark.country,
                                               coordinate: placemark.location?.coordinate ?? coordinate))
            }
            self?.locationPersistence.setLocations(locations, for: coordinate)
            promise.succeed(value: locations)
        }
        geoCoder.reverseGeocodeLocation(location, completionHandler: handler)
        return promise
    }
}
