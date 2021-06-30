import Foundation
import MapKit
import Future
import RuuviOntology
import RuuviLocation

struct LocationApple: Location {
    var city: String?
    var country: String?
    var coordinate: CLLocationCoordinate2D
}

public final class RuuviLocationServiceApple: RuuviLocationService {
    private let locationPersistence = LocationPersistenceImpl()

    public init() {}

    public func search(query: String) -> Future<[Location], RuuviLocationError> {
        let promise = Promise<[Location], RuuviLocationError>()
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { (response, error) in
            guard let response = response else {
                if let error = error {
                    promise.fail(error: .map(error))
                } else {
                    promise.fail(error: .callbackErrorAndResultAreNil)
                }
                return
            }
            var locations = [LocationApple]()
            for item in response.mapItems {
                locations.append(
                    LocationApple(
                        city: item.placemark.locality,
                        country: item.placemark.country,
                        coordinate: item.placemark.coordinate
                    )
                )
            }
            promise.succeed(value: locations)
        }
        return promise.future
    }

    public func reverseGeocode(
        coordinate: CLLocationCoordinate2D
    ) -> Future<[Location], RuuviLocationError> {
        if let locations = locationPersistence.locations(for: coordinate) {
            let promise = Promise<[Location], RuuviLocationError>()
            promise.succeed(value: locations)
            return promise.future
        } else {
            return getReverseGeocodeLocation(coordinate: coordinate).future
        }
    }
}
// MARK: - Private
extension RuuviLocationServiceApple {
    private func getReverseGeocodeLocation(
        coordinate: CLLocationCoordinate2D
    ) -> Promise<[Location], RuuviLocationError> {
        let promise = Promise<[Location], RuuviLocationError>()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let geoCoder = CLGeocoder()
        let handler: CLGeocodeCompletionHandler = { [weak self] (placemarks, error) in
            guard let placemarks = placemarks else {
                if let error = error {
                    promise.fail(error: .map(error))
                } else {
                    promise.fail(error: .callbackErrorAndResultAreNil)
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
