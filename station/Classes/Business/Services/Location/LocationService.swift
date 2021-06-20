import Foundation
import Future
import CoreLocation
import RuuviOntology

protocol LocationService {
    func search(query: String) -> Future<[Location], RUError>
    func reverseGeocode(coordinate: CLLocationCoordinate2D) -> Future<[Location], RUError>
}
